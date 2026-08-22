module Spree
  module ImagesHelper
    # render an image tag with a spree image variant
    # it also automatically scales the width and height by 2x to look great on retina screens
    #
    # @param image [ActiveStorage::Attachment, Spree::Media] the image to render.
    #   A Spree::Media row whose bytes live elsewhere (a DAM-hosted image, an
    #   external video's provider thumbnail) renders at the address its host
    #   serves, since there is no attachment to build a variant from.
    # @param options [Hash] options for the image tag
    # @option options [Integer] :width the width of the image
    # @option options [Integer] :height the height of the image
    # @option options [Symbol] :variant use a preprocessed named variant (e.g., :mini, :small, :medium, :large, :xlarge)
    # @return [String, nil] the image tag, or nil when there is nothing to render
    def spree_image_tag(image, options = {})
      return unless image

      # A hosted still has no attachment to vary, so the variable?/attached?
      # guards below would reject it — spree_image_url answers it directly.
      hosted = image.respond_to?(:hosted_still_url) && image.still_image.nil? && image.hosted_still_url.present?

      unless hosted
        return unless image.variable?
        return if image.respond_to?(:attached?) && !image.attached?
      end

      url_options = if options[:variant].present?
                      { variant: options[:variant] }
                    else
                      { width: options[:width], height: options[:height], format: options[:format] }
                    end

      image_tag(
        spree_image_url(image, url_options),
        options.except(:variant, :format)
      )
    end

    # The URL for a spree image at the requested size.
    #
    # @param image [ActiveStorage::Attachment, Spree::Media] the image to address.
    #   Media hosted elsewhere answers with its host's own address at every
    #   size — the host keeps the renditions, so there is nothing to resize.
    # @param options [Hash] options for the variant
    # @option options [Integer] :width the width of the image
    # @option options [Integer] :height the height of the image
    # @option options [Symbol] :variant use a preprocessed named variant
    # @option options [String] :format the image format (defaults to webp)
    # @return [String, nil] the URL, or nil when there is nothing to address
    def spree_image_url(image, options = {})
      return unless image

      # A hosted still is never variable — the host keeps its own renditions
      # and serves one address for all of them.
      if image.respond_to?(:hosted_still_url) && image.still_image.nil?
        hosted = image.hosted_still_url
        return hosted if hosted.present?
      end

      return unless image.variable?
      return if image.respond_to?(:attached?) && !image.attached?

      url_helpers = respond_to?(:main_app) ? main_app : Rails.application.routes.url_helpers

      # Use preprocessed named variant if specified (e.g., :mini, :small, :medium, :large, :xlarge)
      if options[:variant].present?
        return url_helpers.cdn_image_url(image.variant(options[:variant]))
      end

      # Dynamic variant generation for width/height options
      width = options[:width]
      height = options[:height]

      # Double dimensions for retina displays
      width *= 2 if width.present?
      height *= 2 if height.present?

      if width.present? && height.present?
        url_helpers.cdn_image_url(
          image.variant(spree_image_variant_options(resize_to_fill: [width, height], format: options[:format]))
        )
      else
        url_helpers.cdn_image_url(
          image.variant(spree_image_variant_options(resize_to_limit: [width, height], format: options[:format]))
        )
      end
    end

    def spree_asset_aspect_ratio(attachment)
      return unless attachment.present?
      return unless attachment.analyzed?

      metadata = attachment.metadata
      aspect_ratio = metadata['aspect_ratio'].presence

      return aspect_ratio if aspect_ratio

      width = metadata['width']&.to_f
      return unless width

      height = metadata['height']&.to_f
      return unless height
      return if height.zero?

      w = width.to_f
      h = height.to_f

      # Always return width / height, flipping if needed
      ratio = if h > w
                h / w
              elsif h < w
                w / h
              else
                # h == w, square image
                1.0
              end

      ratio.round(3)
    end

    # convert images to webp with some sane optimization defaults
    # it also automatically scales the width and height by 2x to look great on retina screens
    #
    # @param options [Hash] options for the image variant
    # @option options [Integer] :width the width of the image
    # @option options [Integer] :height the height of the image
    #
    # @note The key order matters for variation digest matching with preprocessed variants.
    #       Active Storage reorders keys alphabetically, so use: format, resize_to_fill/limit, saver
    # @note Use string values (not symbols) for format because variation keys are JSON-encoded
    #       in URLs and JSON converts symbols to strings, causing digest mismatches.
    def spree_image_variant_options(options = {})
      format_opt = options[:format]&.to_s
      saver_options = format_opt == "png" ? png_saver_options : Spree::Media::WEBP_SAVER_OPTIONS
      format = format_opt || "webp"

      # Build hash in alphabetical order to match Active Storage's key ordering
      result = {}
      result[:format] = format
      result[:resize_to_fill] = options[:resize_to_fill] if options[:resize_to_fill]
      result[:resize_to_limit] = options[:resize_to_limit] if options[:resize_to_limit]
      result[:saver] = saver_options
      result
    end

    private

    def png_saver_options
      {
        strip: true,
        compression_level: 8,
        interlace: true
      }
    end
  end
end

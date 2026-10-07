module Spree
  module ImagesHelper
    def spree_image_url(image, options = {})
      return unless image
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

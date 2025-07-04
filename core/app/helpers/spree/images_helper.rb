module Spree
  module ImagesHelper
    # render an image tag with a spree image variant
    # it also automatically scales the width and height by 2x to look great on retina screens
    #
    # @param image [ActiveStorage::Attachment] the image to render
    # @param options [Hash] options for the image tag
    # @option options [Integer] :width the width of the image
    # @option options [Integer] :height the height of the image
    def spree_image_tag(image, options = {})
      image_tag(
        spree_image_url(image, { width: options[:width], height: options[:height], format: options[:format] }),
        options
      )
    end

    def spree_image_url(image, options = {})
      return unless image
      return unless image.variable?
      return if image.respond_to?(:attached?) && !image.attached?
      url_helpers = respond_to?(:main_app) ? main_app : Rails.application.routes.url_helpers
      width = options[:width]
      height = options[:height]

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
    def spree_image_variant_options(options = {})
      {
        saver: options[:format] == :png ? png_variant_options : webp_variant_options,
        format: options[:format] || :webp
      }.merge(options.except(:format))
    end

    private

    def webp_variant_options
      {
        strip: true,
        quality: 75,
        lossless: false,
        alpha_q: 85,
        reduction_effort: 6,
        smart_subsample: true
      }
    end

    def png_variant_options
      {
        strip: true,
        compression_level: 8,
        interlace: true
      }
    end
  end
end

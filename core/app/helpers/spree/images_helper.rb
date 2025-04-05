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
        spree_image_url(image, { width: options[:width], height: options[:height] }),
        options
      )
    end

    def spree_image_url(image, options = {})
      width = options[:width]
      height = options[:height]

      width = width * 2 if width.present?
      height = height * 2 if height.present?

      return unless image.attached?
      return unless image.variable?

      if width.present? && height.present?
        main_app.cdn_image_url(
          image.variant(spree_image_variant_options(resize_to_fill: [width, height]))
        )
      else
        main_app.cdn_image_url(
          image.variant(spree_image_variant_options(resize_to_limit: [width, height]))
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

      w, h = width.to_f, height.to_f

      # Always return width / height, flipping if needed
      if h > w
        ratio = h / w
      elsif h < w
        ratio = w / h
      else
        # h == w, square image
        ratio = 1.0
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
        saver: {
          strip: true,
          quality: 75,
          lossless: false,
          alpha_q: 85,
          reduction_effort: 6,
          smart_subsample: true
        },
        format: :webp
      }.merge(options)
    end
  end
end

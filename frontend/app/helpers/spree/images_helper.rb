module Spree
  module ImagesHelper
    def plp_and_carousel_image(product, image_class = '')
      image = default_image_for_product_or_variant(product)

      image_url = if image.present?
                    main_app.url_for(image.url('plp'))
                  else
                    asset_path('noimage/plp.png')
                  end

      image_style = image&.style(:plp)

      lazy_image(
        src: image_url,
        srcset: carousel_image_source_set(image),
        alt: product.name,
        width: image_style&.dig(:width) || 278,
        height: image_style&.dig(:height) || 371,
        class: "product-component-image d-block mw-100 #{image_class}"
      )
    end

    def lazy_image(src:, alt:, width:, height:, srcset: '', **options)
      # We need placeholder image with the correct size to prevent page from jumping
      placeholder = "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20#{width}%20#{height}'%3E%3C/svg%3E"

      image_tag placeholder, data: { src: src, srcset: srcset }, class: "#{options[:class]} lazyload", alt: alt
    end

    def carousel_image_source_set(image)
      return '' unless image

      widths = { lg: 1200, md: 992, sm: 768, xs: 576 }
      set = []
      widths.each do |key, value|
        file = main_app.url_for(image.url("plp_and_carousel_#{key}"))

        set << "#{file} #{value}w"
      end
      set.join(', ')
    end

    def image_source_set(name)
      widths = {
        desktop: '1200',
        tablet_landscape: '992',
        tablet_portrait: '768',
        mobile: '576'
      }
      set = []
      widths.each do |key, value|
        filename = key == :desktop ? name : "#{name}_#{key}"
        file = asset_path("#{filename}.jpg")

        set << "#{file} #{value}w"
      end
      set.join(', ')
    end

    def set_image_alt(image)
      return image.alt if image.alt.present?
    end
  end
end

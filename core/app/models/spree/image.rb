module Spree
  class Image < Asset
    include Spree::Image::Configuration::ActiveStorage
    include Rails.application.routes.url_helpers
    include Spree::ImageMethods

    after_commit :touch_product_variants, if: :should_touch_product_variants?, on: :update

    # In Rails 5.x class constants are being undefined/redefined during the code reloading process
    # in a rails development environment, after which the actual ruby objects stored in those class constants
    # are no longer equal (subclass == self) what causes error ActiveRecord::SubclassNotFound
    # Invalid single-table inheritance type: Spree::Image is not a subclass of Spree::Image.
    # The line below prevents the error.
    self.inheritance_column = nil

    def styles
      self.class.styles.map do |_, size|
        width, height = size.chop.split('x').map(&:to_i)

        {
          url: generate_url(size: size),
          size: size,
          width: width,
          height: height
        }
      end
    end

    def style(name)
      size = self.class.styles[name]
      return unless size

      width, height = size.chop.split('x').map(&:to_i)

      {
        url: generate_url(size: size),
        size: size,
        width: width,
        height: height
      }
    end

    def style_dimensions(name)
      size = self.class.styles[name]
      width, height = size.chop.split('x').map(&:to_i)

      {
        width: width,
        height: height
      }
    end

    def plp_url
      Spree::Deprecation.warn "Image#plp_url is deprecated. Use variant(:large) instead."
      generate_url(size: self.class.styles[:large])
    end

    private

    def touch_product_variants
      viewable.product.variants.touch_all
    end

    def should_touch_product_variants?
      return false unless viewable.is_a?(Spree::Variant)
      return false unless viewable.is_master?
      return false unless viewable.product.has_variants?
      return false unless saved_change_to_position?

      true
    end
  end
end

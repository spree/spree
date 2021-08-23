module Spree
  class Image < ImageAsset
    include Configuration::ActiveStorage

    # In Rails 5.x class constants are being undefined/redefined during the code reloading process
    # in a rails development environment, after which the actual ruby objects stored in those class constants
    # are no longer equal (subclass == self) what causes error ActiveRecord::SubclassNotFound
    # Invalid single-table inheritance type: Spree::Image is not a subclass of Spree::Image.
    # The line below prevents the error.
    self.inheritance_column = nil

    def styles
      self.class.styles.map do |_, size|
        width, height = size.chop.split('x')

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

      width, height = size.chop.split('x')

      {
        url: generate_url(size: size),
        size: size,
        width: width,
        height: height
      }
    end

    def style_dimensions(name)
      size = self.class.styles[name]
      width, height = size.chop.split('x')

      {
        width: width,
        height: height
      }
    end

    def plp_url
      generate_url(size: self.class.styles[:plp_and_carousel])
    end
  end
end

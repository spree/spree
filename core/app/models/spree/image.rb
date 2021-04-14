module Spree
  class Image < Asset
    include Configuration::ActiveStorage
    include Rails.application.routes.url_helpers

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
          url: polymorphic_path(attachment.variant(
                                  gravity: 'center',
                                  resize: size,
                                  extent: size,
                                  background: 'snow2',
                                  quality: 80
                                ), only_path: true),
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
        url: polymorphic_path(attachment.variant(
                                gravity: 'center',
                                resize: size,
                                extent: size,
                                background: 'snow2',
                                quality: 80
                              ), only_path: true),
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
      size = self.class.styles[:plp_and_carousel]
      variant = attachment.variant(
        gravity: 'center',
        resize: size,
        extent: size,
        background: 'snow2',
        quality: 80
      )

      polymorphic_path(variant, only_path: true)
    end
  end
end

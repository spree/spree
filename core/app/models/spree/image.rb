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
        width, height = size[/(\d+)x(\d+)/].split('x')

        {
          url: polymorphic_path(attachment.variant(resize: size), only_path: true),
          width: width,
          height: height
        }
      end
    end
  end
end

module Spree
  class TaxonImage < Asset
    include Configuration::ActiveStorage
    include Rails.application.routes.url_helpers
    include ::Spree::ImageMethods

    def styles
      self.class.styles.map do |_, size|
        width, height = size[/(\d+)x(\d+)/].split('x').map(&:to_i)

        {
          url: generate_url(size: size),
          size: size,
          width: width,
          height: height
        }
      end
    end
  end
end

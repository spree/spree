module Spree
  class TaxonImage < Asset
    include Configuration::ActiveStorage
    include Rails.application.routes.url_helpers
    include ::Spree::ImageMethods

    def styles
      self.class.styles.map do |_, size|
        width, height = size[/(\d+)x(\d+)/].split('x').map(&:to_i)

        {
          url: polymorphic_path(attachment.variant(resize_to_limit: [width, height]), only_path: true),
          width: width,
          height: height
        }
      end
    end
  end
end

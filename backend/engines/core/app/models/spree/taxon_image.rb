module Spree
  # @deprecated Use Spree::Taxon#image (Active Storage) instead. Will be removed in Spree 5.5.
  class TaxonImage < Asset
    include Spree::TaxonImage::Configuration::ActiveStorage
    include Rails.application.routes.url_helpers
    include Spree::ImageMethods

    after_initialize do
      Spree::Deprecation.warn(
        'Spree::TaxonImage is deprecated and will be removed in Spree 5.5. ' \
        'Please use Spree::Taxon#image (Active Storage) instead.'
      )
    end

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

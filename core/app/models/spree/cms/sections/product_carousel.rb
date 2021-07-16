module Spree::Cms::Sections
  class ProductCarousel < Spree::CmsSection
    after_initialize :default_values

    LINKED_RESOURCE_TYPE = ['Spree::Taxon']

    private

    def default_values
      self.fit ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

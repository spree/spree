module Spree::Cms::Sections
  class FeaturedArticle < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:title, :subtitle, :button_text, :rte_content], coder: JSON
    store :settings, accessors: [:gutters], coder: JSON

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product', 'Spree::CmsPage']

    def gutters?
      gutters == 'Gutters'
    end

    private

    def default_values
      self.gutters ||= 'No Gutters'
      self.fit ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

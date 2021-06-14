module Spree::Cms::Sections
  class FeaturedArticle < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:title, :subtitle, :button_text, :rte_content], coder: JSON

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product', 'Spree::CmsPage']

    private

    def default_values
      self.fit ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

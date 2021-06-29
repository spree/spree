module Spree::Cms::Sections
  class FeaturedArticle < Spree::CmsSection
    before_save :reset_link_attributes
    after_initialize :default_values

    store :content, accessors: [:title, :subtitle, :button_text, :rte_content], coder: JSON
    store :settings, accessors: [:gutters], coder: JSON

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product', 'Spree::CmsPage']

    def gutters?
      gutters == 'Gutters'
    end

    def screen?
      fit == 'Screen'
    end

    private

    def reset_link_attributes
      if linked_resource_type_changed?
        self.linked_resource_id = nil
      end
    end

    def default_values
      self.gutters ||= 'No Gutters'
      self.fit ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

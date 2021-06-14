module Spree::Cms::Sections
  class FullScreenHeroImage < Spree::CmsSection
    after_initialize :default_values

    store :content, accessors: [:title, :button_text], coder: JSON
    store :settings, accessors: [:gutters], coder: JSON

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product']

    def gutters_sizes
      ['Use gutters', 'No Gutters']
    end

    def gutters?
      gutters == 'Use gutters'
    end

    private

    def default_values
      self.fit ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

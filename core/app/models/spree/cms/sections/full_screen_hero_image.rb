module Spree::Cms::Sections
  class FullScreenHeroImage < Spree::CmsSection
    after_initialize :default_values

    store :options, accessors: [:title, :button_text], coder: JSON

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product']

    def widths
      ['Full']
    end

    private

    def default_values
      self.width ||= 'Full'
      self.fit ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

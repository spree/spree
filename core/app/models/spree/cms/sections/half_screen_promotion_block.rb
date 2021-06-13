module Spree::Cms::Sections
  class HalfScreenPromotionBlock < Spree::CmsSection
    after_initialize :default_values

    store :options, accessors: [:title, :subtitle], coder: JSON

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product']

    # Overide this per section type
    def widths
      ['Half']
    end

    private

    def default_values
      self.width ||= 'Half'
      self.fit ||= 'Container'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

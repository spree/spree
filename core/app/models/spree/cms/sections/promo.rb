module Spree::Cms::Sections
  class Promo < Spree::CmsSection
    after_initialize :default_values

    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::Icon'
    accepts_nested_attributes_for :icon, reject_if: :all_blank

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

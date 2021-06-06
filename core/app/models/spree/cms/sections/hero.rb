module Spree::Cms::Sections
  class Hero < Spree::CmsSection
    after_initialize :default_values

    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::Icon'
    accepts_nested_attributes_for :icon, reject_if: :all_blank

    LINKED_RESOURCE_TYPE = ['Spree::Taxon', 'Spree::Product']

    def widths
      ['Full']
    end

    private

    def default_values
      self.width ||= 'Full'
      self.boundary ||= 'Screen'
      self.linked_resource_type ||= 'Spree::Taxon'
    end
  end
end

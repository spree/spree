module Spree::Cms::Sections
  class Hero < Spree::CmsSection
    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::Icon'
    accepts_nested_attributes_for :icon, reject_if: :all_blank

    def links_to
      ['Spree::Taxon', 'Spree::Product']
    end

    def widths
      ['Edge-to-Edge', 'Full', 'Half']
    end
  end
end

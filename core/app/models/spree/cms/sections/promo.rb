module Spree::Cms::Sections
  class Promo < Spree::CmsSection
    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::Icon'
    accepts_nested_attributes_for :icon, reject_if: :all_blank

    def links_to
      ['Spree::Taxon', 'Spree::Product']
    end

    def widths
      ['Half']
    end
  end
end

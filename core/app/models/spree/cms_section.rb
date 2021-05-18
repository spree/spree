module Spree
  class CmsSection < Spree::Base
    acts_as_list scope: :cms_page
    belongs_to :cms_page

    default_scope { order(position: :asc) }

    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::Icon'
    accepts_nested_attributes_for :icon, reject_if: :all_blank

    SECTION_WIDTHS = ['Full', 'Half']
    SECTION_TYPES = ['Text Block', 'Hero']
  end
end

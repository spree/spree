module Spree
  class CmsSection < Spree::Base
    include Spree::DisplayLink

    acts_as_list scope: :cms_page
    belongs_to :cms_page

    belongs_to :linked_resource, polymorphic: true

    default_scope { order(position: :asc) }

    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::Icon'
    accepts_nested_attributes_for :icon, reject_if: :all_blank

    WIDTHS = ['Edge-to-Edge', 'Full', 'Half']
    TYPES = ['Spree::Cms::Sections::Hero',
                     'Spree::Cms::Sections::Promo',
                     'Spree::Cms::Sections::Featured Atricle']

    LINKS_TO = []
  end
end

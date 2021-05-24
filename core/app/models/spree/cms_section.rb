module Spree
  class CmsSection < Spree::Base
    include Spree::DisplayLink

    acts_as_list scope: :cms_page
    belongs_to :cms_page

    belongs_to :linked_resource, polymorphic: true

    default_scope { order(position: :asc) }

    has_one :icon, as: :viewable, dependent: :destroy, class_name: 'Spree::Icon'
    accepts_nested_attributes_for :icon, reject_if: :all_blank

    SECTION_WIDTHS = ['Edge-to-Edge', 'Full', 'Half']
    SECTION_TYPES = ['Text Block', 'Hero', 'Promo', 'Featured Atricle']

    SECTION_LINKS_TO = ['Spree::Taxon', 'Spree::Product']
  end
end

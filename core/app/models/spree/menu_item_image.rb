# frozen_string_literal: true

module Spree
  class MenuItemImage < Spree::Asset
    has_one_attached :attachment

    MENU_ITEM_IMAGE_TYPES = %i[png jpg jpeg gif svg]

    validates :attachment, attached: true, content_type: MENU_ITEM_IMAGE_TYPES
  end
end

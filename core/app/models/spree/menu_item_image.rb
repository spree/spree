# frozen_string_literal: true

module Spree
  class MenuItemImage < Spree::Asset
    has_one_attached :attachment

    validates :attachment, attached: true, content_type: %i[png jpg jpeg gif svg]
  end
end

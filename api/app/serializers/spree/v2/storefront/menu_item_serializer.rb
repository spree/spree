module Spree
  module V2
    module Storefront
      class MenuItemSerializer < BaseSerializer
        set_type :menu_item

        attributes :name, :subtitle, :destination, :code, :new_window, :parent_id, :lft, :rgt, :depth

        attribute :is_root do |menu_item|
          menu_item.root?
        end

        attribute :is_child do |menu_item|
          menu_item.child?
        end

        attribute :is_leaf do |menu_item|
          menu_item.leaf?
        end

        has_one :image,
                object_method_name: :image_asset,
                id_method_name: :image_asset,
                record_type: :image,
                serializer: :image

        belongs_to :menu
      end
    end
  end
end

module Spree
  module V2
    module Storefront
      class MenuItemSerializer < BaseSerializer
        set_type :menu_item

        attributes :code, :name, :subtitle, :link, :new_window, :lft, :rgt, :depth

        attribute :is_container do |menu_item|
          menu_item.container?
        end

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
                object_method_name: :icon,
                id_method_name: :icon_id,
                record_type: :image,
                serializer: :image

        belongs_to :menu
        belongs_to :parent, record_type: :menu_item, serializer: :menu_item

        has_many   :children, record_type: :menu_item, serializer: :menu_item
      end
    end
  end
end

module Spree
  module Admin
    class MenuItemsController < ResourceController
      belongs_to 'spree/menu'

      before_action :load_data

      def collection_url
        spree.edit_admin_menu_path(@menu)
      end

      def location_after_save
        spree.edit_admin_menu_menu_item_path(@menu, @menu_item)
      end

      def load_data
        @menu_item_types = Spree::MenuItem::ITEM_TYPE
      end
    end
  end
end

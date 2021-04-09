module Spree
  module Admin
    class MenuItemsController < ResourceController
      belongs_to 'spree/menu'

      def index; end

      def collection_url
        spree.edit_admin_menu_path(@menu)
      end

      def location_after_save
        spree.edit_admin_menu_menu_item_path(@menu, @menu_item)
      end
    end
  end
end

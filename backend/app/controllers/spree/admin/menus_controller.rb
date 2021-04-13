module Spree
  module Admin
    class MenusController < ResourceController
      before_action :load_data
      before_action :load_menu_items_ordered, only: :edit

      def index; end

      private

      def location_after_save
        spree.edit_admin_menu_path(@menu)
      end

      private

      def load_data
        @stores = Spree::Store.all
      end

      def load_menu_items_ordered
        @menu_items_in_order = @menu.menu_items.order('lft ASC')
      end
    end
  end
end

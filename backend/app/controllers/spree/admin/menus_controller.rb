module Spree
  module Admin
    class MenusController < ResourceController
      before_action :load_menu_items_ordered, only: [:edit, :update]

      def index; end

      private

      def location_after_save
        spree.edit_admin_menu_path(@menu)
      end

      def load_menu_items_ordered
        @menu_items_in_order = @menu.menu_items.order(:lft)
      end
    end
  end
end

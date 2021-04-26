module Spree
  module Admin
    class MenusController < ResourceController
      def index; end

      private

      def location_after_save
        spree.edit_admin_menu_path(@menu)
      end
    end
  end
end

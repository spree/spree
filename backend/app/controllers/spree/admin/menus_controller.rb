module Spree
  module Admin
    class MenusController < ResourceController
      before_action :load_data

      def index; end

      private

      def location_after_save
        spree.edit_admin_menu_path(@menu)
      end

      def load_data
        @stores = Spree::Store.all
      end
    end
  end
end

module Spree
  module Admin
    class MenusController < ResourceController
      before_action :load_data
      def index; end

      private

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}
        @collection = super

        @search = @collection.ransack(params[:q])
        @collection = @search.result.page(params[:page]).per(params[:per_page])
      end

      def location_after_save
        spree.edit_admin_menu_path(@menu)
      end

      def load_data
        Spree::Menu.refresh_for_locations
        @menu_locations = Spree::MenuLocation.all
      end
    end
  end
end

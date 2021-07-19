module Spree
  module Admin
    class MenusController < ResourceController
      def index; end

      private

      def scope
        current_store.menus
      end

      def find_resource
        scope.find(params[:id])
      end

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}
        @collection = scope

        @search = @collection.ransack(params[:q])
        @collection = @search.result.page(params[:page]).
                      per(params[:per_page] || Spree::Backend::Config[:menus_per_page])
      end

      def location_after_save
        spree.edit_admin_menu_path(@menu)
      end
    end
  end
end

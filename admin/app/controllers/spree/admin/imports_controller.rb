module Spree
  module Admin
    class ExportsController < ResourceController
      include ActiveStorage::SetCurrent # Needed for ActiveStorage to work on development env

      new_action.before :assign_params
      create.before :set_user

      # GET /admin/imports/:id
      def show
        @rows = @object.rows.includes(:item)
      end

      protected

      def set_user
        @object.user = try_spree_current_user
      end

      def location_after_save
        spree.admin_import_path(@object)
      end

      def assign_params
        @object.type = permitted_resource_params[:type] if available_types.map(&:to_s).include?(permitted_resource_params[:type])
      end

      def permitted_resource_params
        params.require(:import).permit(permitted_import_attributes)
      end

      def available_types
        Spree::Import.available_types
      end
    end
  end
end

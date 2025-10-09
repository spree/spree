module Spree
  module Admin
    class ImportsController < ResourceController
      include ActiveStorage::SetCurrent # Needed for ActiveStorage to work on development env

      new_action.before :assign_params
      create.before :set_user
      create.before :set_owner

      add_breadcrumb_icon 'table-import'

      # GET /admin/imports/:id
      def show
        add_breadcrumb @object.display_name, spree.admin_import_path(@object)
        @rows = @object.rows.includes(:item)
      end

      protected

      def set_user
        @object.user = try_spree_current_user
      end

      def set_owner
        @object.owner = current_store
      end

      def location_after_save
        spree.admin_import_path(@object)
      end

      def assign_params
        @object.type = available_types.map(&:to_s).find { |type| type == params.dig(:import, :type) } || available_types.first.to_s
      end

      def available_types
        Spree::Import.available_types
      end

      def permitted_resource_params
        params.require(:import).permit(permitted_import_attributes)
      end

      def choose_layout
        return 'turbo_rails/frame' if turbo_frame_request?

        'spree/admin_minimal'
      end

      def create_turbo_stream_enabled?
        true
      end
    end
  end
end

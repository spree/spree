module Spree
  module Admin
    class ImportsController < ResourceController
      include ActiveStorage::SetCurrent # Needed for ActiveStorage to work on development env

      new_action.before :assign_params
      create.before :assign_params
      create.before :set_user
      create.before :set_owner
      create.after :start_mapping

      # GET /admin/imports/:id
      def show
        if @object.status == 'mapping'
          @mappings = @object.mappings
          @mappings_options = @object.unmapped_file_columns.map { |file_column| [file_column, file_column] }
        else
          @rows = @object.rows.processed.includes(:item)
        end
      end

      # PUT /admin/imports/:id/complete_mapping
      def complete_mapping
        @object.complete_mapping! if @object.mapping_done?

        redirect_to spree.admin_import_path(@object)
      end

      protected

      def set_user
        @object.user = try_spree_current_user
      end

      def set_owner
        @object.owner = current_store
      end

      def start_mapping
        @object.start_mapping!
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
        params.require(:import).permit(permitted_import_attributes + @object.preferences.keys.map { |key| "preferred_#{key}" })
      end

      def choose_layout
        return 'turbo_rails/frame' if turbo_frame_request? && action_name != 'show'

        'spree/admin_wizard'
      end
    end
  end
end

module Spree
  module Admin
    class ExportsController < ResourceController
      include ActiveStorage::SetCurrent # Needed for ActiveStorage to work on development env

      include Spree::Admin::SettingsConcern

      new_action.before :assign_params
      create.before :set_user
      create.after :remember_results_url

      def show
        redirect_to @object.attachment.url, status: :see_other, allow_other_host: true
      end

      protected

      def create_turbo_stream_enabled?
        true
      end

      def message_after_create
        Spree.t('admin.export_created')
      end

      def collection_includes
        [:user, attachment_attachment: :blob]
      end

      def set_user
        @object.user = try_spree_current_user
      end

      # The export-done email links wherever the creating surface serves the
      # file — for the legacy admin that is this export's download page.
      def remember_results_url
        @object.update!(results_url: spree.admin_export_url(@object))
      end

      def location_after_save
        spree.admin_exports_path
      end

      def assign_params
        available_type =  available_types.map(&:to_s).find { |t| t == permitted_resource_params[:type] }
        @object = @object.becomes!(available_type.constantize) if available_type.present?
        @object.search_params = permitted_resource_params[:search_params]
      end

      def permitted_resource_params
        params.require(:export).permit(permitted_export_attributes)
      end

      def available_types
        Spree::Export.available_types + ['Spree::Exports::Customers']
      end
    end
  end
end

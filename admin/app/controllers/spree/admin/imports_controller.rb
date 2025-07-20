module Spree
  module Admin
    class ImportsController < ResourceController
      include ActiveStorage::SetCurrent # Needed for ActiveStorage to work on development env

      new_action.before :assign_params
      create.after :run_import_async
      create.before :set_user

      def show
        redirect_to @object.attachment.url, status: :see_other, allow_other_host: true
      end

      def errors
        @errors = @object.error_details
      end

      protected

      def create_turbo_stream_enabled?
        true
      end

      def message_after_create
        Spree.t('admin.import_created')
      end

      def collection
        return @collection if @collection.present?

        @collection = super

        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'
        @search = @collection.ransack(params[:q])
        @collection = @search.result.includes(:user, attachment_attachment: :blob).page(params[:page])
      end

      def run_import_async
        Spree::Imports::ExecuteJob.perform_later(@object.id)
      end

      def set_user
        @object.user = try_spree_current_user
      end

      def location_after_save
        spree.admin_imports_path
      end

      def assign_params
        @object.type = permitted_resource_params[:type] if Spree::Import.available_types.map(&:to_s).include?(permitted_resource_params[:type])
      end

      def permitted_resource_params
        params.require(:import).permit(permitted_import_attributes)
      end
    end
  end
end

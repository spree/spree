module Spree
  module Admin
    class ExportsController < ResourceController
      include ActiveStorage::SetCurrent # Needed for ActiveStorage to work on development env

      new_action.before :assign_params
      create.before :set_user

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

      def collection
        return @collection if @collection.present?

        @collection = super

        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'
        @search = @collection.ransack(params[:q])
        @collection = @search.result.includes(:user, attachment_attachment: :blob).page(params[:page])
      end

      def set_user
        @object.user = try_spree_current_user
      end

      def location_after_save
        spree.admin_exports_path
      end

      def assign_params
        @object.type = params.dig(:export, :type) if Spree::Export.available_types.map(&:to_s).include?(params.dig(:export, :type))
        @object.search_params = params.dig(:export, :search_params)
      end
    end
  end
end

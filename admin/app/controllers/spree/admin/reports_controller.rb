module Spree
  module Admin
    class ReportsController < ResourceController
      include ActiveStorage::SetCurrent

      before_action :set_user, only: [:new, :create]

      def show
        redirect_to @object.attachment.url, status: :see_other, allow_other_host: true
      end

      private

      def set_user
        @object.user = try_spree_current_user
      end

      def create_turbo_stream_enabled?
        true
      end

      def message_after_create
        Spree.t('admin.report_created')
      end

      def location_after_save
        spree.admin_reports_path
      end

      def build_resource
        model_class.new(store: current_store, date_from: params[:date_from], date_to: params[:date_to], currency: params[:currency])
      end

      def model_class
        @model_class = if params[:type].present?
                         report_type = "Spree::Reports::#{params[:type].classify}"
                         if allowed_report_types.include?(report_type)
                           report_type.constantize
                         else
                           raise 'Unknown report type'
                         end
                       else
                         Spree::Report
                       end
      end

      def allowed_report_types
        Rails.application.config.spree.reports.map(&:to_s)
      end
    end
  end
end

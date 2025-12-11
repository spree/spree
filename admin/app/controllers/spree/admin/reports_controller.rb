module Spree
  module Admin
    class ReportsController < ResourceController
      include ActiveStorage::SetCurrent

      add_breadcrumb_icon 'chart-bar'
      add_breadcrumb Spree.t(:reports), :admin_reports_path

      before_action :set_user, only: [:new, :create]
      before_action :load_report_line_items, only: [:new, :create]

      def show
        redirect_to @object.attachment.url, status: :see_other, allow_other_host: true
      end

      private

      def set_user
        @object.user = try_spree_current_user
      end

      def load_report_line_items
        @report_line_items = @object.line_items
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
        report_resource = model_class.new(
          store: current_store,
          date_from: parse_date_param(params[:date_from]),
          date_to: parse_date_param(params[:date_to])&.end_of_day,
          currency: params[:currency]
        )
        report_resource.vendor_id = params[:vendor_id] if defined?(Spree::Vendor)
        report_resource
      end

      def model_class
        report_type = params[:type] || params.dig(:report, :type)
        @model_class = if report_type.present?
                         # Find the actual class from allowed types rather than using constantize
                         if allowed_report_types.include?(report_type)
                           report_class = report_type
                         else
                           report_type = "Spree::Reports::#{report_type.classify}"
                           report_class = allowed_report_types.find { |type| type == report_type }
                         end

                         if report_class
                           Object.const_get(report_class)
                         else
                           raise 'Unknown report type'
                         end
                       else
                         Spree::Report
                       end
      end

      def allowed_report_types
        Spree.reports.map(&:to_s)
      end

      def permitted_resource_params
        attributes = params.require(:report).permit(permitted_report_attributes)
        attributes[:date_from] = parse_date_param(attributes[:date_from]) if attributes[:date_from].present?
        attributes[:date_to] = parse_date_param(attributes[:date_to])&.end_of_day if attributes[:date_to].present?
        attributes
      end
    end
  end
end

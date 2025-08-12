module Spree
  module Admin
    class ExportsController < ResourceController
      include ActiveStorage::SetCurrent # Needed for ActiveStorage to work on development env
      include Spree::Admin::OrdersFiltersHelper

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
        @object.type = permitted_resource_params[:type] if available_types.map(&:to_s).include?(permitted_resource_params[:type])
        @object.search_params = permitted_resource_params[:search_params]
      end

      def process_search_params_for_export(search_params, export_type)
        return search_params unless search_params.present?
        return search_params unless export_type == 'Spree::Exports::Orders'

        parsed_params = JSON.parse(search_params.to_s).deep_symbolize_keys
        processed_params = params_to_filters(search_params: parsed_params)

        processed_params.each do |key, value|
          if value.is_a?(Time)
            processed_params[key] = value.to_s
          end
        end

        processed_params.to_json
      rescue JSON::ParserError
        search_params
      end

      def permitted_resource_params
        attributes = params.require(:export).permit(permitted_export_attributes)

        if attributes[:type] == 'Spree::Exports::Orders' && attributes[:search_params].present?
          attributes[:search_params] = process_search_params_for_export(attributes[:search_params], attributes[:type])
        end

        attributes
      end

      def available_types
        Spree::Export.available_types + ['Spree::Exports::Customers']
      end
    end
  end
end

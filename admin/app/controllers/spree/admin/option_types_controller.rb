module Spree
  module Admin
    class OptionTypesController < ResourceController
      before_action :setup_new_option_value, only: :edit

      include ProductsBreadcrumbConcern
      add_breadcrumb Spree.t(:options), :admin_option_types_path

      before_action :add_breadcrumbs

      private

      def setup_new_option_value
        @option_type.option_values.build if @option_type.option_values.empty?
      end

      def add_breadcrumbs
        if @option_type.present? && @option_type.persisted?
          add_breadcrumb @option_type.presentation, spree.edit_admin_option_type_path(@option_type)
        end
      end

      def permitted_resource_params
        params.require(:option_type).permit(permitted_option_type_attributes)
      end
    end
  end
end

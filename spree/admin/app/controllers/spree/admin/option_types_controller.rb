module Spree
  module Admin
    class OptionTypesController < ResourceController
      before_action :setup_option_values, only: [:edit, :new]

      include ProductsBreadcrumbConcern
      add_breadcrumb Spree.t(:options), :admin_option_types_path

      before_action :add_breadcrumbs

      private

      def setup_option_values
        per_page = Spree::Admin::RuntimeConfig.admin_option_values_per_page
        @option_values_page = [params[:option_values_page].to_i, 1].max
        @option_values_total = @option_type.option_values.count

        if @option_values_total == 0
          @option_type.option_values.build
          @option_values = @option_type.option_values
          @option_values_pages = 1
        else
          @option_values = @option_type.option_values.order(:position)
                             .offset((@option_values_page - 1) * per_page)
                             .limit(per_page)
          @option_values_pages = (@option_values_total.to_f / per_page).ceil
        end
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

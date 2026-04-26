module Spree
  module Admin
    class OptionTypesController < ResourceController
      before_action :setup_option_values, only: [:edit, :new]

      include ProductsBreadcrumbConcern
      add_breadcrumb Spree.t(:options), :admin_option_types_path

      before_action :add_breadcrumbs

      OPTION_VALUES_PER_PAGE = 50

      private

      def setup_option_values
        @option_values_page = [params[:option_values_page].to_i, 1].max
        @option_values_total = @option_type.option_values.count

        if @option_values_total == 0
          @option_type.option_values.build
          @option_values = @option_type.option_values
          @option_values_pages = 1
        else
          @option_values = @option_type.option_values.order(:position)
                             .offset((@option_values_page - 1) * OPTION_VALUES_PER_PAGE)
                             .limit(OPTION_VALUES_PER_PAGE)
          @option_values_pages = (@option_values_total.to_f / OPTION_VALUES_PER_PAGE).ceil
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

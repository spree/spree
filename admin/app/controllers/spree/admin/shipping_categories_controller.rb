module Spree
  module Admin
    class ShippingCategoriesController < ResourceController
      add_breadcrumb Spree.t(:shipping_categories), :admin_shipping_categories_path

      private

      def permitted_resource_params
        params.require(:shipping_category).permit(permitted_shipping_category_attributes)
      end
    end
  end
end

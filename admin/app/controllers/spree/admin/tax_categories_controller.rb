module Spree
  module Admin
    class TaxCategoriesController < ResourceController
      add_breadcrumb Spree.t(:tax_categories), :admin_tax_categories_path

      private

      def permitted_resource_params
        params.require(:tax_category).permit(permitted_tax_category_attributes)
      end
    end
  end
end

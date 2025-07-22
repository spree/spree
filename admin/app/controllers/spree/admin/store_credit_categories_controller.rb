module Spree
  module Admin
    class StoreCreditCategoriesController < ResourceController
      private

      def permitted_resource_params
        params.require(:store_credit_category).permit(permitted_store_credit_category_attributes)
      end
    end
  end
end

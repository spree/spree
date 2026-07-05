module Spree
  module Admin
    class ReturnItemsController < ResourceController
      private

      def location_after_save
        spree.edit_admin_order_customer_return_path(@return_item.customer_return.order, @return_item.customer_return)
      end

      def permitted_resource_params
        params.require(:return_item).permit(permitted_return_item_attributes)
      end
    end
  end
end

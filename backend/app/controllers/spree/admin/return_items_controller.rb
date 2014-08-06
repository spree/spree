module Spree
  module Admin
    class ReturnItemsController < ResourceController
      def location_after_save
        url_for([:edit, :admin, @return_item.customer_return.order, @return_item.customer_return])
      end
    end
  end
end

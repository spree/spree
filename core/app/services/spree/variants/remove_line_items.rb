module Spree
  module Variants
    class RemoveLineItems
      prepend Spree::ServiceModule::Base

      def call(variant:, order_ids:)
        orders = Spree::Order.where(id: order_ids)

        orders.each do |order|
          Spree::Dependencies.cart_remove_item_service.constantize.call(variant: variant, order: order)
        end

        success(orders)
      end
    end
  end
end


module Spree
  module Variants
    class RemoveLineItems
      prepend Spree::ServiceModule::Base

      def call(variant:)
        cart_remove_item_service = Spree::Dependencies.cart_remove_item_service.constantize
        incomplete_orders = variant.orders.where.not(state: 'complete')
        incomplete_orders.each do |order|
          cart_remove_item_service.call(variant: variant, order: order)
        end

        success(incomplete_orders)
      end
    end
  end
end

module Spree
  module Orders
    # Draft-order twin of the cart service — order: is the canonical keyword
    # on this side, delegating onto the shared implementation.
    #
    # The order workflow leaves totals to whoever runs it, and nothing else
    # runs after a single removal, so this service recalculates the order.
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, options: {})
        ActiveRecord::Base.transaction do
          result = Spree::Carts::RemoveLineItem.call(cart: order, line_item: line_item, options: options)
          return result if result.failure?

          Spree::Orders::Recalculate.call(order: order)
          result
        end
      end
    end
  end
end

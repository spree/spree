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
        result = nil

        # requires_new: callers already hold the order's row lock, and a
        # rollback in a joined transaction would be swallowed.
        ActiveRecord::Base.transaction(requires_new: true) do
          result = Spree::Carts::RemoveLineItem.call(cart: order, line_item: line_item, options: options)
          next if result.failure?

          recalculation = Spree::Orders::Recalculate.call(order: order)
          next if recalculation.success?

          result = recalculation
          raise ActiveRecord::Rollback
        end

        result
      end
    end
  end
end

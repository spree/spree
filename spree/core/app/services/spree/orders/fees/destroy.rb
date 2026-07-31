module Spree
  module Orders
    module Fees
      # Removes a fee row and re-sums the order totals.
      class Destroy
        prepend Spree::ServiceModule::Base

        # @param order [Spree::Order]
        # @param fee [Spree::Fee]
        # @return [Spree::ServiceModule::Result] value is the destroyed row
        def call(order:, fee:)
          order.with_lock do
            fee.destroy!
            Spree.order_recalculate_totals_workflow.call(order: order)
          end

          success(fee)
        end
      end
    end
  end
end

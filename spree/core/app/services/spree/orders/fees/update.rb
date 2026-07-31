module Spree
  module Orders
    module Fees
      # Updates a fee row and re-sums the order totals.
      class Update
        prepend Spree::ServiceModule::Base

        # @param order [Spree::Order]
        # @param fee [Spree::Fee]
        # @param attributes [Hash, ActionController::Parameters]
        # @return [Spree::ServiceModule::Result] value is the fee row
        def call(order:, fee:, attributes:)
          updated = order.with_lock do
            next false unless fee.update(attributes)

            Spree.order_recalculate_totals_workflow.call(order: order)
            true
          end

          updated ? success(fee) : failure(fee)
        end
      end
    end
  end
end

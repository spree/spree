module Spree
  module Orders
    module Fees
      # Creates a fee row (surcharge by default) and re-sums the order
      # totals — part of the sanctioned post-placement edit path.
      class Create
        prepend Spree::ServiceModule::Base

        # @param order [Spree::Order]
        # @param attributes [Hash, ActionController::Parameters] may carry a
        #   line_item/fulfillment target; order-level when neither is given
        # @return [Spree::ServiceModule::Result] value is the fee row
        def call(order:, attributes:)
          fee = order.fees.build(attributes.reverse_merge(kind: 'surcharge'))

          created = order.with_lock do
            next false unless fee.save

            Spree.order_recalculate_totals_workflow.call(order: order)
            true
          end

          created ? success(fee) : failure(fee)
        end
      end
    end
  end
end

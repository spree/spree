module Spree
  module Orders
    module Discounts
      # Removes a manual discount row and re-sums the order totals.
      # Promotion-sourced rows are recalculation-owned and refused.
      class Destroy
        prepend Spree::ServiceModule::Base

        # @param order [Spree::Order]
        # @param discount [Spree::Discount]
        # @return [Spree::ServiceModule::Result] value is the destroyed row
        def call(order:, discount:)
          return failure(discount, :promotion_discount_not_editable) if discount.promotion?

          order.with_lock do
            discount.destroy!
            Spree.order_recalculate_totals_workflow.call(order: order)
          end

          success(discount)
        end
      end
    end
  end
end

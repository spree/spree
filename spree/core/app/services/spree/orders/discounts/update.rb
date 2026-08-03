module Spree
  module Orders
    module Discounts
      # Updates a manual discount row and re-sums the order totals — part of
      # the sanctioned post-placement edit path. Promotion-sourced rows are
      # recalculation-owned and refused.
      class Update
        prepend Spree::ServiceModule::Base

        # @param order [Spree::Order]
        # @param discount [Spree::Discount]
        # @param attributes [Hash, ActionController::Parameters]
        # @return [Spree::ServiceModule::Result] value is the discount row
        def call(order:, discount:, attributes:)
          return failure(discount, :promotion_discount_not_editable) if discount.promotion?

          updated = order.with_lock do
            next false unless discount.update(attributes)

            Spree.order_recalculate_totals_workflow.call(order: order)
            true
          end

          updated ? success(discount) : failure(discount)
        end
      end
    end
  end
end

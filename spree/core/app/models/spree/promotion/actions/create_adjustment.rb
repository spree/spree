module Spree
  class Promotion
    module Actions
      # A whole-order discount. There are no order-level discount rows: the
      # computed amount is distributed proportionally across the line items
      # (docs/plans/6.0-split-adjustments.md, Resolved Question 1), so taxes,
      # refunds, and marketplace order-splitting always see per-line money.
      class CreateAdjustment < PromotionAction
        include Spree::CalculatedAdjustments

        before_validation -> { self.calculator ||= Calculator::FlatPercentItemTotal.new }

        def self.additional_permitted_attributes
          [calculator: [:type, { preferences: {} }]]
        end

        def perform(options = {})
          order = options[:order]
          shares = distributed_amounts(order)

          results = order.line_items.map do |line_item|
            upsert_discount_line(order, line_item, shares.fetch(line_item.id, 0))
          end

          results.include?(true)
        end

        # The line item's deterministic share of the whole-order discount —
        # recalculation reproduces exactly the split activation wrote.
        def compute_amount(line_item)
          distributed_amounts(line_item.order).fetch(line_item.id, 0)
        end

        # Whole-order actions compete order-wide as groups during
        # recalculation (Adjusters::Promotion), not per line item.
        def order_level?
          true
        end

        def order_total(order)
          order.item_total + order.ship_total - order.shipping_discount
        end

        # The whole-order discount split across the order's line items
        # (largest-remainder, see Spree::Adjustments::DistributeAmount).
        # Adjusters consume this batch instead of calling compute_amount per
        # line, so the split is computed once per recalculation pass.
        #
        # @param order [Spree::Order]
        # @return [Hash{Integer => BigDecimal}] line item id => share
        def distributed_amounts(order)
          Spree::Adjustments::DistributeAmount.new(
            amount: compute_order_discount(order),
            line_items: order.line_items
          ).call
        end

        private

        def compute_order_discount(order)
          [order_total(order), compute(order)].min * -1
        end
      end
    end
  end
end

module Spree
  module Purchase
    # Money readers shared by Spree::Cart and Spree::Order. The raw
    # +outstanding_balance+ stays host-specific on purpose: an order nets
    # reimbursement payouts and inverts on cancellation, a cart is plain
    # total minus payments.
    module Totals
      # @return [Integer] total units across line items
      def quantity
        line_items.sum(:quantity)
      end

      # @return [Boolean]
      def outstanding_balance?
        outstanding_balance != 0
      end

      # Balance still to collect after applied store credit, never negative.
      #
      # @return [BigDecimal]
      def amount_due
        [outstanding_balance - total_applied_store_credit, 0].max
      end

      # @return [Boolean]
      def paid?
        total.positive? && payment_total >= total
      end

      # Total fulfillment discount applied by promotions, as a positive amount.
      #
      # @return [BigDecimal]
      def fulfillment_discount
        discounts.for_fulfillments.sum(:amount) * -1
      end
    end
  end
end

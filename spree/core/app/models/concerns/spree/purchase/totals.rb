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

      # Re-sums what the customer has actually paid, and nothing else. A
      # payment settling moves only the payment side of the ledger — item
      # and delivery money is the totals workflow's business, and
      # re-deriving it here would overwrite figures a caller set
      # deliberately.
      #
      # Shared by Cart and Order: both carry payment_total, and payments
      # settle on a cart during checkout.
      #
      # @return [BigDecimal] the persisted payment_total
      def refresh_payment_total!
        settled = payments.completed.includes(:refunds).sum { |payment| payment.amount - payment.refunds.sum(:amount) }
        update_column(:payment_total, settled)
        self.payment_total = settled
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

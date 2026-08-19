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
        # One atomic statement: the sum and the write have to be a single
        # step, or two handlers settling different payments interleave and
        # the older one writes its smaller total last, leaving the record
        # short-paid with no further event coming to correct it.
        #
        # Deliberately not with_lock, which refuses a record carrying
        # unsaved changes — callers legitimately hold dirty attributes while
        # a payment is destroyed (cart teardown, order merging), and this
        # must never disturb their in-memory state.
        settled = settled_payments_arel
        self.class.where(id: id).update_all(payment_total: settled)
        self.payment_total = self.class.where(id: id).pick(:payment_total)
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

      private

      # Completed payments less their refunds, as a scalar subquery so the
      # sum and the write are one statement.
      #
      # @return [Arel::Nodes::Grouping]
      def settled_payments_arel
        payments_table = Spree::Payment.arel_table
        refunds_table = Spree::Refund.arel_table

        settled = payments_table.project(payments_table[:id]).
                  where(payments_table[owner_foreign_key].eq(id)).
                  where(payments_table[:status].eq('completed'))

        captured = payments_table.project(payments_table[:amount].sum).
                   where(payments_table[owner_foreign_key].eq(id)).
                   where(payments_table[:status].eq('completed'))

        refunded = refunds_table.project(refunds_table[:amount].sum).
                   where(refunds_table[:payment_id].in(settled))

        Arel::Nodes::NamedFunction.new(
          'COALESCE',
          [
            Arel::Nodes::Subtraction.new(
              Arel::Nodes::NamedFunction.new('COALESCE', [Arel::Nodes::Grouping.new(captured), Arel.sql('0')]),
              Arel::Nodes::NamedFunction.new('COALESCE', [Arel::Nodes::Grouping.new(refunded), Arel.sql('0')])
            ),
            Arel.sql('0')
          ]
        )
      end

      # @return [Symbol] the column payments use to point at this record
      def owner_foreign_key
        is_a?(Spree::Cart) ? :cart_id : :order_id
      end
    end
  end
end

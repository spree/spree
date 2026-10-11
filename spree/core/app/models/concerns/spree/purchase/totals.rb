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

      # What promotion calculators take a share of: the line amounts less the
      # free gifts, so a gift never enlarges a percentage off the order.
      #
      # @return [BigDecimal]
      def amount
        line_items.sum(BigDecimal('0'), &:amount) - gift_amount
      end

      # The list price of the units gift promotions give away. The gift keeps
      # its price on its line and is paid for by a discount, so anything
      # measuring what the shopper spends has to take it out.
      #
      # @param promotion [Spree::Promotion, nil] the promotion doing the
      #   measuring; its own gifts are always taken out, since a gift cannot
      #   be what qualifies the promotion giving it away
      # @param own_gift_only [Boolean] true while deciding whether another
      #   promotion gives its gift, so two gift promotions with spend
      #   thresholds do not each wait on the other
      # @return [BigDecimal]
      def gift_amount(promotion: nil, own_gift_only: false)
        return BigDecimal('0') if line_items.empty?

        excluded_gift_promo_actions = gift_promo_actions(promotion, own_gift_only).select do |action|
          action.promotion_id == promotion&.id || action.gives_away?(self)
        end
        return BigDecimal('0') if excluded_gift_promo_actions.empty?

        line_items.sum(BigDecimal('0')) do |line_item|
          gifted_quantity = excluded_gift_promo_actions.sum { |action| action.gifted_quantity_of(line_item) }
          Spree::Money::Rounding.to_currency(line_item.price * [gifted_quantity, line_item.quantity].min, line_item.currency)
        end
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
        # updated_at moves with it, or the API validates a cached response
        # against an unchanged timestamp and serves the pre-payment figure.
        settled = settled_payments_arel
        self.class.where(id: id).update_all(payment_total: settled, updated_at: Time.current)
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

      # What has to be paid before this purchase can be placed and
      # dispatched — the whole total unless an arrangement collects only part
      # of it up front. See {Spree::Purchases::AmountDueAtCheckout}, which is
      # where a deposit or net terms would answer differently.
      #
      # @return [BigDecimal]
      def amount_due_at_checkout
        Spree.purchase_amount_due_at_checkout_service.new.call(purchase: self)
      end

      # Total fulfillment discount applied by promotions, as a positive amount.
      #
      # @return [BigDecimal]
      def fulfillment_discount
        discounts.for_fulfillments.sum(:amount) * -1
      end

      private

      # Other promotions' gifts are looked for among the promotions a
      # recalculation writes discounts for, so a gift leaves the measure
      # exactly when its discount can be written.
      def gift_promo_actions(promotion, own_gift_only)
        own = promotion ? promotion.actions.grep(Spree::Promotion::Actions::CreateLineItems) : []
        return own if own_gift_only

        discounting_ids = promotion_ids + Spree::Promotion.held_by_saved_coupon_code(self).map(&:id)
        return own if discounting_ids.empty?

        gifting_cart_variants = Spree::PromotionActionLineItem.
                                where(variant_id: line_items.map(&:variant_id)).
                                select(:promotion_action_id)
        others = Spree::Promotion::Actions::CreateLineItems.
                 where(promotion_id: discounting_ids, id: gifting_cart_variants).
                 includes(:promotion, :promotion_action_line_items)

        (own + others.to_a).uniq(&:id)
      end

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

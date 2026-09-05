module Spree
  module Purchase
    # Deposit terms and what they mean for this purchase's money — shared by
    # Spree::Cart and Spree::Order.
    #
    # A cart resolves its terms from the delivery rate it has selected, so
    # changing the shipping choice changes what checkout asks for. An order
    # reads the snapshot frozen at placement and never resolves again: the
    # deal was struck then (docs/plans/6.0-6.1-b2b-payment-terms.md).
    module PaymentTerms
      extend ActiveSupport::Concern

      # @return [Spree::PaymentTerms, nil]
      def payment_terms_snapshot
        return @payment_terms_snapshot if defined?(@payment_terms_snapshot)

        @payment_terms_snapshot = Spree::PaymentTerms.from_snapshot(payment_terms) || resolved_payment_terms
      end

      # What this purchase must be paid before it can complete. The whole
      # total unless terms say a deposit, which is every retail order.
      #
      # @return [BigDecimal]
      def amount_due_at_checkout
        terms = payment_terms_snapshot
        return total.to_d if terms.nil?

        terms.amount_due_now(total, currency: currency)
      end

      # The money story a surface tells: what was due now, whether it has
      # been paid, and what is left with the merchant's own name for it.
      #
      # @return [Spree::PaymentSchedule]
      def payment_schedule
        terms = payment_terms_snapshot
        due_now = amount_due_at_checkout

        Spree::PaymentSchedule.new(
          amount_due_now: due_now,
          deposit_amount: (due_now if terms&.deposit?),
          deposit_paid: payment_total.to_d >= due_now,
          outstanding_balance: outstanding_balance,
          balance_due_label: terms&.balance_due_label
        )
      end

      # Dropped on reload, so a cart whose delivery choice changed in the
      # same request resolves again rather than answering from the rate it
      # no longer ships under.
      def reload(*)
        remove_instance_variable(:@payment_terms_snapshot) if defined?(@payment_terms_snapshot)
        super
      end

      private

      # A cart follows whatever it is shipping under; an order has its
      # snapshot and never asks again.
      def resolved_payment_terms
        return if is_a?(Spree::Order)

        # Any shipment asking for a deposit sets the terms for the purchase.
        # Taking whichever rate happened to be created first would lose the
        # deposit the moment a wholesale buyer added one parcel item, since
        # carts split per delivery profile.
        fulfillments.filter_map(&:selected_delivery_rate).
          filter_map { |rate| Spree::PaymentTerms.from_delivery_rate(rate) }.
          find(&:deposit?)
      end
    end
  end
end

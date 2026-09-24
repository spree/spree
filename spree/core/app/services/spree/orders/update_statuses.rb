module Spree
  module Orders
    # The ONLY writer of +payment_status+ and +fulfillment_status+.
    # Derive-then-persist: statuses are recomputed from payment/refund/
    # fulfillment records and stored in indexed columns so admin filtering
    # keeps working. Triggered from payment/refund/fulfillment/return event
    # subscribers — never inline from controllers.
    class UpdateStatuses
      prepend Spree::ServiceModule::Base

      PAYMENT_STATUSES = Spree::Order::PAYMENT_STATUSES
      SETTLED_PAYMENT_STATUSES = %w[paid overcharged].freeze

      def call(order:)
        settled_now = false

        # Derived and written under the order's row lock, so two runs cannot
        # interleave: one that derived before another settled the order would
        # otherwise write its older status back and let a later run announce
        # the payment a second time. The status is read from the locked row
        # rather than reloaded, which would discard what the caller has not
        # saved yet.
        Spree::Order.transaction do
          committed_status = Spree::Order.where(id: order.id).lock.pick(:payment_status)
          payment_status = payment_status_for(order)

          order.update_columns(
            payment_status: payment_status,
            fulfillment_status: fulfillment_status_for(order),
            updated_at: Time.current
          )

          settled_now = settled?(payment_status) && !settled?(committed_status)
        end

        # Announced from here rather than from the payment, so the payload
        # already carries the status and payment total it announces.
        order.publish_event('order.paid') if settled_now

        success(order)
      end

      private

      def settled?(payment_status)
        payment_status.in?(SETTLED_PAYMENT_STATUSES)
      end

      # Money is quantized to currency precision before comparing, and
      # granted refunds are subtracted from the target total — the two rules
      # every derivation implementation gets wrong first.
      def payment_status_for(order)
        currency = ::Money::Currency.find(order.currency) || ::Money::Currency.find('USD')
        precision = currency.exponent

        captured, authorized, refunded = money_for(order).map { |amount| quantize(amount, precision) }
        target = quantize(order.total, precision) - refunded
        net_captured = captured - refunded

        if order.canceled? && net_captured <= 0 && captured.positive?
          'voided'
        elsif refunded.positive? && net_captured <= 0
          'refunded'
        elsif refunded.positive?
          'partially_refunded'
        elsif captured.zero? && authorized.zero?
          'none'
        elsif captured.zero?
          'authorized'
        elsif net_captured > target
          'overcharged'
        elsif net_captured >= target
          'paid'
        else
          'partially_paid'
        end
      end

      # What has been authorised, captured and refunded against this order.
      #
      # An order placed in a split checkout owns no payments — the customer
      # made one payment against the group — so its figures come from its share
      # of them. That is precisely what a payment split records, and it is why
      # the shares are stored rather than recomputed: once one seller has
      # shipped and been captured while another has not, no proportion of the
      # group's totals can describe either.
      #
      # Refunded spans both ledgers. A refund paid as store credit writes no
      # {Spree::Refund} row, and counting only those rows left an order that
      # had given every penny back still reading `paid`.
      #
      # @return [Array(BigDecimal, BigDecimal, BigDecimal)] captured,
      #   authorized and refunded, in that order
      def money_for(order)
        credited = order.store_credit_refunds.sum(:amount)

        unless order.order_group_id.present?
          return [
            order.payments.valid.completed.sum(:amount),
            order.payments.valid.pending.sum(:amount),
            order.refunds.sum(:amount) + credited
          ]
        end

        splits = order.payment_splits.reload.to_a
        captured = splits.sum(&:captured_amount)

        # Authorized means still to draw: what the shares allow, less what has
        # already been taken against them.
        [captured, splits.sum(&:authorized_amount) - captured, splits.sum(&:refunded_amount) + credited]
      end

      # Rolls the fulfillments up into one word for filtering and display.
      #
      # Canceled fulfillments are ignored unless they are all there is: an
      # order whose second parcel was recalled is still described by the first.
      # A mix that includes anything handed over reads as `partial`; otherwise
      # the shared status stands. `delivered` only when every parcel arrived.
      def fulfillment_status_for(order)
        return 'backorder' if order.backordered?

        statuses = order.fulfillments.reload.pluck(:status).uniq
        return if statuses.empty?

        live = statuses - ['canceled']
        # Every parcel recalled: on a canceled order that is the end of the
        # story, on a placed one the goods are still owed and a new fulfillment
        # is how they go out — so it reads as work remaining, not as canceled.
        return (order.canceled? ? 'canceled' : 'unfulfilled') if live.empty?
        return live.first if live.size == 1

        live.intersect?(%w[fulfilled delivered]) ? 'partial' : 'unfulfilled'
      end

      def quantize(amount, precision)
        Spree::Money::Rounding.quantize(amount, precision)
      end
    end
  end
end

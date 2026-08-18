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

      def call(order:)
        order.update_columns(
          payment_status: payment_status_for(order),
          fulfillment_status: fulfillment_status_for(order),
          updated_at: Time.current
        )
        success(order)
      end

      private

      # Money is quantized to currency precision before comparing, and
      # granted refunds are subtracted from the target total — the two rules
      # every derivation implementation gets wrong first.
      def payment_status_for(order)
        currency = ::Money::Currency.find(order.currency) || ::Money::Currency.find('USD')
        precision = currency.exponent

        captured = quantize(order.payments.valid.completed.sum(:amount), precision)
        authorized = quantize(order.payments.valid.pending.sum(:amount), precision)
        refunded = quantize(order.refunds.sum(:amount), precision)
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
        return 'canceled' if live.empty?
        return live.first if live.size == 1

        live.intersect?(%w[fulfilled delivered]) ? 'partial' : 'unfulfilled'
      end

      def quantize(amount, precision)
        Spree::Money::Rounding.quantize(amount, precision)
      end
    end
  end
end

module Spree
  module Orders
    # The ONLY writer of +payment_status+ and +fulfillment_status+.
    # Derive-then-persist: statuses are recomputed from payment/refund/
    # fulfillment records and stored in indexed columns so admin filtering
    # keeps working. Triggered from payment/refund/fulfillment/return event
    # subscribers — never inline from controllers.
    class RecomputeStatuses
      prepend Spree::ServiceModule::Base

      PAYMENT_STATUSES = %w[none authorized partially_paid paid partially_refunded refunded overcharged voided].freeze

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

      # Domain owned by the fulfillment plan (incl. backorder) — same rollup
      # OrderUpdater#update_fulfillment_status computes.
      def fulfillment_status_for(order)
        Spree::OrderUpdater.new(order).update_fulfillment_status
      end

      def quantize(amount, precision)
        BigDecimal(amount.to_s).round(precision)
      end
    end
  end
end

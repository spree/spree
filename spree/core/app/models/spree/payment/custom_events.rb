# frozen_string_literal: true

module Spree
  class Payment < Spree.base_class
    # Publishes custom payment events beyond basic lifecycle events.
    #
    # Events:
    # - payment.paid: Payment was completed
    # - order.paid: Order is fully paid (no outstanding balance)
    #
    module CustomEvents
      extend ActiveSupport::Concern

      included do
        after_commit :publish_payment_paid_event, on: :update, if: :should_publish_paid_event?
      end

      private

      def should_publish_paid_event?
        return false unless Spree::Events.enabled?
        return false unless status_previously_changed?

        status_previous_change&.last == 'completed'
      end

      def publish_payment_paid_event
        publish_event('payment.paid')

        # order is nil for a cart-owned payment — checkout is still in
        # flight, so there is no order to declare paid yet.
        return if order.nil?

        # Derived from the payment rows rather than order.paid?, which reads
        # payment_total — a column written by the order status subscriber on
        # the payment.completed event that has not been dispatched yet when
        # this after_commit runs. Reading it here (cached or reloaded) sees
        # the pre-settlement figure and the order is never declared paid.
        order.publish_event('order.paid') if order_settled_in_full?
      end

      # @return [Boolean]
      def order_settled_in_full?
        return false unless order.total.to_d.positive?

        settled = order.payments.completed.includes(:refunds).sum { |payment| payment.amount - payment.refunds.sum(:amount) }
        settled >= order.total.to_d
      end
    end
  end
end

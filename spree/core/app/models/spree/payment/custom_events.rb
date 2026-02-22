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
        return false unless state_previously_changed?

        state_previous_change&.last == 'completed'
      end

      def publish_payment_paid_event
        publish_event('payment.paid')
        publish_order_paid_event if order.paid?
      end

      def publish_order_paid_event
        order.publish_event('order.paid')
      end
    end
  end
end

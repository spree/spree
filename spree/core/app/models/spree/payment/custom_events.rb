# frozen_string_literal: true

module Spree
  class Payment < Spree.base_class
    # Publishes custom payment events beyond basic lifecycle events.
    #
    # Events:
    # - payment.paid: Payment was completed
    #
    # order.paid is published by {Spree::Orders::UpdateStatuses} once the
    # order's payment status turns paid.
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
      end
    end
  end
end

# frozen_string_literal: true

module Spree
  class Fulfillment < Spree.base_class
    # Publishes fulfillment lifecycle events beyond the basic Publishable set.
    #
    # Events:
    # - fulfillment.ready:     Fulfillment became ready
    # - fulfillment.fulfilled: Fulfillment was fulfilled
    # - order.fulfilled:       All order fulfillments are fulfilled
    # - fulfillment.canceled:  Fulfillment was canceled
    # - fulfillment.resumed:   Fulfillment was resumed from canceled
    #
    # The legacy shipment.* / order.shipped events are dual-emitted for one
    # release (webhook contract bridge — removed in 6.1).
    #
    # NOTE: These methods are called from the state machine's after_transition
    # callbacks defined in the Fulfillment model, not via ActiveRecord callbacks.
    module CustomEvents
      extend ActiveSupport::Concern

      def publish_fulfillment_ready_event
        return unless Spree::Events.enabled?

        publish_event('fulfillment.ready')
      end

      def publish_fulfillment_fulfilled_event
        return unless Spree::Events.enabled?

        publish_event('fulfillment.fulfilled')
        # Legacy name — removed in 6.1
        publish_event('shipment.shipped')

        # Force reload of fulfillments association to see the new status
        order.fulfillments.reset
        publish_order_fulfilled_event if order.fully_fulfilled?
      end

      def publish_fulfillment_canceled_event
        return unless Spree::Events.enabled?

        publish_event('fulfillment.canceled')
        # Legacy name — removed in 6.1
        publish_event('shipment.canceled')
      end

      def publish_fulfillment_resumed_event
        return unless Spree::Events.enabled?

        publish_event('fulfillment.resumed')
        # Legacy name — removed in 6.1
        publish_event('shipment.resumed')
      end

      # @deprecated Use {#publish_fulfillment_fulfilled_event}; removed in 6.1.
      def publish_shipment_shipped_event
        Spree::Deprecation.warn('Spree::Fulfillment#publish_shipment_shipped_event is deprecated and will be removed in Spree 6.1. Use #publish_fulfillment_fulfilled_event instead.')
        publish_fulfillment_fulfilled_event
      end

      # @deprecated Use {#publish_fulfillment_canceled_event}; removed in 6.1.
      def publish_shipment_canceled_event
        Spree::Deprecation.warn('Spree::Fulfillment#publish_shipment_canceled_event is deprecated and will be removed in Spree 6.1. Use #publish_fulfillment_canceled_event instead.')
        publish_fulfillment_canceled_event
      end

      # @deprecated Use {#publish_fulfillment_resumed_event}; removed in 6.1.
      def publish_shipment_resumed_event
        Spree::Deprecation.warn('Spree::Fulfillment#publish_shipment_resumed_event is deprecated and will be removed in Spree 6.1. Use #publish_fulfillment_resumed_event instead.')
        publish_fulfillment_resumed_event
      end

      private

      def publish_order_fulfilled_event
        order.publish_event('order.fulfilled')
        # Legacy name — removed in 6.1
        order.publish_event('order.shipped')
      end
    end
  end
end

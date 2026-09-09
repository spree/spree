# frozen_string_literal: true

module Spree
  class Fulfillment < Spree.base_class
    # Publishes fulfillment lifecycle events beyond the basic Publishable set.
    #
    # Events:
    # - fulfillment.fulfilled: Fulfillment was handed over
    # - fulfillment.delivered: Receipt was confirmed
    # - order.fulfilled:       All order fulfillments are fulfilled
    # - order.delivered:       All order fulfillments are delivered
    # - fulfillment.canceled:  Fulfillment was canceled
    #
    # The legacy shipment.* / order.shipped events are dual-emitted for one
    # release (webhook contract bridge — removed in 6.1).
    #
    # NOTE: These methods are called from the Spree::Fulfillments workflows,
    # never from ActiveRecord callbacks — publishing is part of the transition
    # the workflow performed, not a side effect of a column changing.
    module CustomEvents
      extend ActiveSupport::Concern

      # @deprecated `ready` is not a status since 6.0; removed in 6.1.
      def publish_fulfillment_ready_event
        Spree::Deprecation.warn('Spree::Fulfillment#publish_fulfillment_ready_event is deprecated and will be removed in Spree 6.1. The ready status no longer exists.')
        nil
      end

      # Whether the customer should be told this fulfillment shipped. Set by
      # the caller (see Spree::Fulfillments::Fulfill) and carried in the event
      # metadata rather than the payload — it is an instruction to subscribers
      # about this one dispatch, not a property of the fulfillment.
      #
      # Defaults to true: anything fulfilling a shipment without expressing an
      # opinion gets the historic behavior.
      attr_writer :notify_customer

      def notify_customer?
        @notify_customer.nil? ? true : !!@notify_customer
      end

      def publish_fulfillment_fulfilled_event
        return unless Spree::Events.enabled?

        metadata = { notify_customer: notify_customer? }

        publish_event('fulfillment.fulfilled', nil, metadata)
        # Legacy name — removed in 6.1
        publish_event('shipment.shipped', nil, metadata)

        # Force reload of fulfillments association to see the new status
        order.fulfillments.reset
        publish_order_fulfilled_event if order.fully_fulfilled?
      end

      def publish_fulfillment_delivered_event
        return unless Spree::Events.enabled?

        publish_event('fulfillment.delivered', nil, { notify_customer: notify_customer? })

        # The association is reloaded for the same reason as above: the caller
        # just wrote this row and the cached copy still shows the old status.
        order.fulfillments.reset
        order.publish_event('order.delivered') if order.fully_delivered?
      end

      def publish_fulfillment_canceled_event
        return unless Spree::Events.enabled?

        publish_event('fulfillment.canceled')
        # Legacy name — removed in 6.1
        publish_event('shipment.canceled')
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

      private

      def publish_order_fulfilled_event
        order.publish_event('order.fulfilled')
        # Legacy name — removed in 6.1
        order.publish_event('order.shipped')
      end
    end
  end
end

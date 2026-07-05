# frozen_string_literal: true

module Spree
  class Shipment < Spree.base_class
    # Publishes custom shipment events beyond basic lifecycle events.
    #
    # Events:
    # - shipment.shipped: Shipment was shipped
    # - order.shipped: All order shipments are shipped
    # - shipment.canceled: Shipment was canceled
    # - shipment.resumed: Shipment was resumed from canceled state
    #
    # NOTE: These methods are called from the state machine's after_transition callbacks
    # defined in the Shipment model, not via ActiveRecord callbacks.
    #
    module CustomEvents
      extend ActiveSupport::Concern

      def publish_shipment_shipped_event
        return unless Spree::Events.enabled?

        publish_event('shipment.shipped')
        # Force reload of shipments association to see the new state
        order.shipments.reset
        publish_order_shipped_event if order.fully_shipped?
      end

      def publish_shipment_canceled_event
        return unless Spree::Events.enabled?

        publish_event('shipment.canceled')
      end

      def publish_shipment_resumed_event
        return unless Spree::Events.enabled?

        publish_event('shipment.resumed')
      end

      private

      def publish_order_shipped_event
        order.publish_event('order.shipped')
      end
    end
  end
end

# frozen_string_literal: true

module Spree
  # Main entry point for the Spree event system.
  #
  # This module provides a clean API for publishing events and subscribing
  # to them. It abstracts the underlying implementation (ActiveSupport::Notifications)
  # allowing for future changes without affecting subscriber code.
  #
  # @example Publishing an event
  #   Spree::Events.publish('order.complete', order.serializable_hash)
  #
  # @example Subscribing with a class
  #   Spree::Events.subscribe('order.complete', OrderCompleteHandler)
  #
  # @example Subscribing with a block
  #   Spree::Events.subscribe('order.complete') do |event|
  #     puts "Order completed: #{event.payload['number']}"
  #   end
  #
  # @example Pattern matching
  #   Spree::Events.subscribe('order.*', OrderAuditLogger)  # All order events
  #   Spree::Events.subscribe('*', GlobalEventLogger)       # All events
  #
  module Events
    # Standard Spree event names
    #
    # This provides a reference for the standard events that Spree publishes.
    # Developers can use these constants or the string versions.
    #
    # @return [Hash<Symbol, String>]
    STANDARD_EVENTS = {
      # Product events
      product_create: 'product.create',
      product_update: 'product.update',
      product_destroy: 'product.destroy',

      # Variant events
      variant_create: 'variant.create',
      variant_update: 'variant.update',
      variant_destroy: 'variant.destroy',

      # Order lifecycle events
      order_create: 'order.create',
      order_update: 'order.update',
      order_destroy: 'order.destroy',
      order_complete: 'order.complete',
      order_cancel: 'order.cancel',
      order_resume: 'order.resume',
      order_approve: 'order.approve',

      # Payment events
      payment_create: 'payment.create',
      payment_complete: 'payment.complete',
      payment_void: 'payment.void',
      payment_refund: 'payment.refund',

      # Shipment events
      shipment_create: 'shipment.create',
      shipment_ship: 'shipment.ship',
      shipment_deliver: 'shipment.deliver',
      shipment_cancel: 'shipment.cancel',

      # Inventory events
      stock_item_update: 'stock_item.update',
      stock_item_low_stock: 'stock_item.low_stock',
      stock_item_out_of_stock: 'stock_item.out_of_stock',

      # User events
      user_create: 'user.create',
      user_update: 'user.update',
      user_password_reset: 'user.password_reset',
      user_signup: 'user.signup',

      # Checkout events
      checkout_progress: 'checkout.progress',
      checkout_complete: 'checkout.complete',

      # Refund events
      refund_create: 'refund.create',

      # Return events
      return_create: 'return.create',
      return_approve: 'return.approve',
      return_cancel: 'return.cancel'
    }.freeze

    class << self
      # Publish an event to all matching subscribers
      #
      # @param name [String] The event name (e.g., 'order.complete')
      # @param payload [Hash] The event payload (should be serializable)
      # @param metadata [Hash] Additional metadata for the event
      # @return [Spree::Event] The published event
      #
      # @example
      #   Spree::Events.publish('product.create', product.serializable_hash)
      #   Spree::Events.publish('order.complete', order.serializable_hash, { user_id: current_user.id })
      #
      def publish(name, payload = {}, metadata = {})
        adapter.publish(name, payload, metadata)
      end

      # Subscribe to an event pattern
      #
      # @param pattern [String] Event pattern (supports wildcards like 'order.*' or '*')
      # @param subscriber [Class, Proc, nil] The subscriber class or callable
      # @param options [Hash] Subscription options
      # @option options [Boolean] :async (true) Whether to run async via ActiveJob
      # @yield [event] Block to execute when event occurs (alternative to subscriber param)
      # @yieldparam event [Spree::Event] The event object
      # @return [void]
      #
      # @example With a subscriber class
      #   Spree::Events.subscribe('order.complete', SendConfirmationEmail)
      #
      # @example With a block
      #   Spree::Events.subscribe('order.complete') { |event| puts event.name }
      #
      # @example With pattern matching
      #   Spree::Events.subscribe('order.*', OrderAuditLogger)
      #
      # @example Synchronous execution
      #   Spree::Events.subscribe('order.complete', MyHandler, async: false)
      #
      def subscribe(pattern, subscriber = nil, options = {}, &block)
        subscriber = block if block_given?
        raise ArgumentError, 'Must provide a subscriber class, callable, or block' unless subscriber

        adapter.subscribe(pattern, subscriber, options)
      end

      # Unsubscribe from an event pattern
      #
      # @param pattern [String] Event pattern
      # @param subscriber [Class, Proc] The subscriber to remove
      # @return [Boolean] true if removed, false if not found
      def unsubscribe(pattern, subscriber)
        adapter.unsubscribe(pattern, subscriber)
      end

      # Get the event registry
      #
      # @return [Spree::Events::Registry]
      def registry
        @registry ||= Registry.new
      end

      # Get the adapter instance
      #
      # @return [Spree::Events::Adapters::ActiveSupportNotifications]
      def adapter
        @adapter ||= Adapters::ActiveSupportNotifications.new(registry)
      end

      # Activate the event system (called during Rails initialization)
      def activate!
        adapter.activate!
      end

      # Reset the event system (useful for testing)
      def reset!
        adapter.deactivate! if @adapter
        @registry = nil
        @adapter = nil
      end

      # List all registered subscriber patterns
      #
      # @return [Array<String>]
      def patterns
        registry.patterns
      end

      # List all subscriptions
      #
      # @return [Array<Spree::Events::Registry::Subscription>]
      def subscriptions
        registry.all_subscriptions
      end

      # Check if events are enabled
      #
      # Events can be temporarily disabled using Spree::Events.disable { ... }
      #
      # @return [Boolean]
      def enabled?
        !RequestStore.store[:spree_events_disabled]
      end

      # Temporarily disable events within a block
      #
      # @yield Block during which events are disabled
      # @return [Object] Return value of the block
      #
      # @example
      #   Spree::Events.disable do
      #     # Events published here won't trigger subscribers
      #     order.complete!
      #   end
      #
      def disable
        previous = RequestStore.store[:spree_events_disabled]
        RequestStore.store[:spree_events_disabled] = true
        yield
      ensure
        RequestStore.store[:spree_events_disabled] = previous
      end

      # Get standard event name by key
      #
      # @param key [Symbol] The event key
      # @return [String, nil] The event name
      def event_name(key)
        STANDARD_EVENTS[key]
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'events/registry'
require_relative 'events/adapters/base'
require_relative 'events/adapters/active_support_notifications'

module Spree
  # Main entry point for the Spree event system.
  #
  # This module provides a clean API for publishing events and subscribing
  # to them. It abstracts the underlying implementation (ActiveSupport::Notifications)
  # allowing for future changes without affecting subscriber code.
  #
  # @example Publishing an event
  #   Spree::Events.publish('order.completed', order.serializable_hash)
  #
  # @example Subscribing with a class
  #   Spree::Events.subscribe('order.completed', OrderCompletedHandler)
  #
  # @example Subscribing with a block
  #   Spree::Events.subscribe('order.completed') do |event|
  #     puts "Order completed: #{event.payload['number']}"
  #   end
  #
  # @example Pattern matching
  #   Spree::Events.subscribe('order.*', OrderAuditLogger)  # All order events
  #   Spree::Events.subscribe('*', GlobalEventLogger)       # All events
  #
  module Events
    class << self
      # Publish an event to all matching subscribers
      #
      # @param name [String] The event name (e.g., 'order.complete')
      # @param payload [Hash] The event payload (should be serializable)
      # @param metadata [Hash] Additional metadata for the event
      # @return [Spree::Event] The published event
      #
      # @example
      #   Spree::Events.publish('product.created', product.serializable_hash)
      #   Spree::Events.publish('order.completed', order.serializable_hash, { user_id: current_user.id })
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
      #   Spree::Events.subscribe('order.completed', SendConfirmationEmail)
      #
      # @example With a block
      #   Spree::Events.subscribe('order.completed') { |event| puts event.name }
      #
      # @example With pattern matching
      #   Spree::Events.subscribe('order.*', OrderAuditLogger)
      #
      # @example Synchronous execution
      #   Spree::Events.subscribe('order.completed', MyHandler, async: false)
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
      # The adapter class can be configured via Spree.events_adapter_class
      # Default: Spree::Events::Adapters::ActiveSupportNotifications
      #
      # @return [Object] the configured adapter instance
      def adapter
        @adapter ||= Spree.events_adapter_class.new(registry)
      end

      # Activate the event system (called during Rails initialization)
      # Also registers all subscribers from Spree.subscribers
      # This method is idempotent - calling it multiple times has no effect
      def activate!
        return if registry.size > 0

        register_subscribers!
        adapter.activate!
      end

      # Reset the event system (useful for testing)
      def reset!
        adapter.deactivate! if @adapter
        @registry = nil
        @adapter = nil
      end

      # Register all subscribers from Spree.subscribers
      #
      # This is called automatically during Rails initialization.
      # Can also be called in tests after reset! to re-register subscribers.
      #
      # In development, class objects in Spree.subscribers may become stale after
      # code reload (Zeitwerk creates new class objects). We resolve the constant
      # fresh from the class name to ensure we're using the reloaded class.
      #
      # @return [void]
      def register_subscribers!
        return unless defined?(Spree) && Spree.respond_to?(:subscribers)

        Spree.subscribers&.each do |subscriber|
          # Resolve the subscriber constant fresh to handle code reload in development
          # The array may contain stale class objects after Zeitwerk reload
          resolved_subscriber = resolve_subscriber(subscriber)
          next unless resolved_subscriber

          resolved_subscriber.subscription_patterns.each do |pattern|
            subscribe(pattern, resolved_subscriber, resolved_subscriber.subscription_options)
          end
        end
      end

      # Resolve a subscriber to its current class object
      #
      # In development, Zeitwerk may have reloaded the class, creating a new
      # class object while the old one is still referenced in Spree.subscribers.
      # This method resolves the constant fresh to get the current class.
      #
      # @param subscriber [Class, String] The subscriber class or class name
      # @return [Class, nil] The resolved class or nil if not found
      def resolve_subscriber(subscriber)
        return subscriber unless Rails.env.development? || Rails.env.test?

        class_name = subscriber.is_a?(String) ? subscriber : subscriber.name
        return nil unless class_name

        class_name.constantize
      rescue NameError => e
        Rails.logger.warn "[Spree Events] Could not resolve subscriber #{class_name}: #{e.message}"
        nil
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
    end
  end
end

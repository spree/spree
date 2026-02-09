# frozen_string_literal: true

module Spree
  module Events
    # Registry for managing event subscribers across different adapters.
    #
    # The registry provides an adapter-agnostic way to track subscriptions.
    # This allows Spree to support different event backends (ActiveSupport::Notifications,
    # Kafka, Redis Pub/Sub, etc.) while maintaining a consistent subscription API.
    #
    # Thread safety: Uses a Mutex for safe concurrent access during subscription
    # registration/unregistration, which may happen during Rails initialization
    # or hot reloading in development.
    #
    # @example
    #   registry = Spree::Events::Registry.new
    #   registry.register('order.*', MySubscriber, async: true)
    #   registry.subscriptions_for('order.complete') # => [Subscription]
    #
    class Registry
      # Immutable subscription data using Ruby 3.2+ Data class
      Subscription = Data.define(:pattern, :subscriber, :options) do
        def async?
          options.fetch(:async, true)
        end
      end

      def initialize
        @subscriptions = []
        @mutex = Mutex.new
      end

      # Register a subscriber for an event pattern
      #
      # @param pattern [String] Event pattern (supports wildcards like 'order.*')
      # @param subscriber [Class, Proc] The subscriber class or callable
      # @param options [Hash] Subscription options (:async, etc.)
      # @return [Subscription]
      def register(pattern, subscriber, options = {})
        subscription = Subscription.new(
          pattern: pattern.to_s,
          subscriber: subscriber,
          options: options.freeze
        )

        @mutex.synchronize { @subscriptions << subscription }
        subscription
      end

      # Unregister a subscriber
      #
      # @param pattern [String] Event pattern
      # @param subscriber [Class, Proc] The subscriber to remove
      # @return [Boolean] true if removed
      def unregister(pattern, subscriber)
        @mutex.synchronize do
          original_size = @subscriptions.size
          @subscriptions.reject! { |s| s.pattern == pattern.to_s && s.subscriber == subscriber }
          @subscriptions.size < original_size
        end
      end

      # Find all subscriptions matching an event name
      #
      # @param event_name [String] The event name
      # @return [Array<Subscription>]
      def subscriptions_for(event_name)
        @mutex.synchronize do
          @subscriptions.select { |s| Spree::Event.matches?(event_name, s.pattern) }
        end
      end

      # @return [Array<Subscription>]
      def all_subscriptions
        @mutex.synchronize { @subscriptions.dup }
      end

      # @return [Array<String>] Unique patterns
      def patterns
        @mutex.synchronize { @subscriptions.map(&:pattern).uniq }
      end

      # @return [Integer]
      def size
        @mutex.synchronize { @subscriptions.size }
      end

      # @param pattern [String]
      # @return [Boolean]
      def registered?(pattern)
        @mutex.synchronize { @subscriptions.any? { |s| s.pattern == pattern.to_s } }
      end

      def clear!
        @mutex.synchronize { @subscriptions.clear }
      end
    end
  end
end

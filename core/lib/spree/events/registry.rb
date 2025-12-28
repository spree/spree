# frozen_string_literal: true

module Spree
  module Events
    # Registry for managing event subscribers.
    #
    # The registry keeps track of all registered subscribers and their
    # event subscriptions. It supports pattern matching for event names.
    #
    # @example Registering a subscriber
    #   registry = Spree::Events::Registry.new
    #   registry.register('order.complete', MySubscriber)
    #
    # @example Finding subscribers for an event
    #   registry.subscribers_for('order.complete')
    #   # => [MySubscriber, AnotherSubscriber]
    #
    class Registry
      Subscription = Struct.new(:pattern, :subscriber, :options, keyword_init: true)

      def initialize
        @subscriptions = []
        @mutex = Mutex.new
      end

      # Register a subscriber for an event pattern
      #
      # @param pattern [String] Event pattern (supports wildcards like 'order.*')
      # @param subscriber [Class, Proc] The subscriber class or callable
      # @param options [Hash] Additional options for the subscription
      # @return [Subscription] The created subscription
      def register(pattern, subscriber, options = {})
        subscription = Subscription.new(
          pattern: pattern.to_s,
          subscriber: subscriber,
          options: options
        )

        @mutex.synchronize do
          @subscriptions << subscription
        end

        subscription
      end

      # Unregister a subscriber
      #
      # @param pattern [String] Event pattern
      # @param subscriber [Class, Proc] The subscriber to remove
      # @return [Boolean] true if removed, false if not found
      def unregister(pattern, subscriber)
        @mutex.synchronize do
          original_size = @subscriptions.size
          @subscriptions.reject! do |sub|
            sub.pattern == pattern.to_s && sub.subscriber == subscriber
          end
          @subscriptions.size < original_size
        end
      end

      # Find all subscribers that match an event name
      #
      # @param event_name [String] The event name to match
      # @return [Array<Subscription>] Matching subscriptions
      def subscriptions_for(event_name)
        @mutex.synchronize do
          @subscriptions.select do |subscription|
            Spree::Event.matches?(event_name, subscription.pattern)
          end
        end
      end

      # Get all registered subscriptions
      #
      # @return [Array<Subscription>]
      def all_subscriptions
        @mutex.synchronize { @subscriptions.dup }
      end

      # Get all unique patterns
      #
      # @return [Array<String>]
      def patterns
        @mutex.synchronize { @subscriptions.map(&:pattern).uniq }
      end

      # Clear all subscriptions
      def clear!
        @mutex.synchronize { @subscriptions.clear }
      end

      # Number of subscriptions
      #
      # @return [Integer]
      def size
        @mutex.synchronize { @subscriptions.size }
      end

      # Check if a pattern is registered
      #
      # @param pattern [String]
      # @return [Boolean]
      def registered?(pattern)
        @mutex.synchronize do
          @subscriptions.any? { |sub| sub.pattern == pattern.to_s }
        end
      end
    end
  end
end

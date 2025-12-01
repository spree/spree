# frozen_string_literal: true

module Spree
  module Events
    module Adapters
      # Adapter for ActiveSupport::Notifications backend.
      #
      # This adapter wraps Rails' built-in notification system to provide
      # the Spree event infrastructure. It can be swapped out for other
      # implementations (e.g., Redis pub/sub, Kafka) without changing
      # the subscriber API.
      #
      # @example Publishing an event
      #   adapter = ActiveSupportNotifications.new(registry)
      #   adapter.publish('order.complete', { id: 1 })
      #
      class ActiveSupportNotifications
        NAMESPACE = 'spree'

        attr_reader :registry

        def initialize(registry)
          @registry = registry
          @as_subscription = nil
          @mutex = Mutex.new
        end

        # Publish an event to all matching subscribers
        #
        # @param event_name [String] The event name
        # @param payload [Hash] The event payload
        # @param metadata [Hash] Additional metadata
        # @return [Spree::Event] The published event
        def publish(event_name, payload, metadata = {})
          event = Spree::Event.new(
            name: event_name,
            payload: payload,
            metadata: metadata
          )

          instrument_name = namespaced_event(event_name)

          ::ActiveSupport::Notifications.instrument(instrument_name, event: event) do
            # The block is intentionally empty - we use the instrument
            # to trigger subscribers, not to wrap code execution
          end

          event
        end

        # Subscribe to an event pattern
        #
        # This method registers a subscriber in the registry.
        # The actual AS::N subscription is created once via activate!
        #
        # @param pattern [String] Event pattern (supports wildcards)
        # @param subscriber [Class, Proc] The subscriber
        # @param options [Hash] Subscription options
        def subscribe(pattern, subscriber, options = {})
          # Register in our registry
          registry.register(pattern, subscriber, options)

          # Ensure the global AS::N subscription exists
          ensure_as_subscription
        end

        # Unsubscribe from an event pattern
        #
        # @param pattern [String] Event pattern
        # @param subscriber [Class, Proc] The subscriber to remove
        def unsubscribe(pattern, subscriber)
          registry.unregister(pattern, subscriber)
        end

        # Activate all registered subscriptions
        #
        # This is called during Rails initialization to set up
        # the single AS::N subscription that catches all Spree events.
        def activate!
          ensure_as_subscription
        end

        # Deactivate all AS::N subscriptions
        def deactivate!
          @mutex.synchronize do
            if @as_subscription
              ::ActiveSupport::Notifications.unsubscribe(@as_subscription)
              @as_subscription = nil
            end
          end
        end

        private

        def namespaced_event(event_name)
          "#{event_name}.#{NAMESPACE}"
        end

        # Create a single AS::N subscription that catches all Spree events
        def ensure_as_subscription
          @mutex.synchronize do
            return if @as_subscription

            # Match all events ending with .spree
            @as_subscription = ::ActiveSupport::Notifications.subscribe(/\.#{NAMESPACE}$/) do |_name, _start, _finish, _id, as_payload|
              # Extract our event from the AS::N payload
              event = as_payload[:event]
              next unless event

              # Find and invoke all matching subscribers
              invoke_subscribers(event)
            end
          end
        end

        def invoke_subscribers(event)
          # Check if events are enabled (can be disabled via Spree::Events.disable)
          return unless Spree::Events.enabled?

          subscriptions = registry.subscriptions_for(event.name)

          subscriptions.each do |subscription|
            invoke_subscriber(subscription.subscriber, event, subscription.options)
          rescue StandardError => e
            handle_subscriber_error(e, event, subscription)
          end
        end

        def invoke_subscriber(subscriber, event, options)
          async = options.fetch(:async, true)

          if subscriber.is_a?(Proc)
            # Block subscribers run synchronously
            subscriber.call(event)
          elsif subscriber.respond_to?(:call)
            # Callable objects (including subscriber instances)
            if async && defined?(Spree::Events::SubscriberJob)
              Spree::Events::SubscriberJob.perform_later(subscriber.name, event.to_h)
            else
              subscriber.call(event)
            end
          elsif subscriber.is_a?(Class) && subscriber < Spree::Subscriber
            # Subscriber classes
            if async && defined?(Spree::Events::SubscriberJob)
              Spree::Events::SubscriberJob.perform_later(subscriber.name, event.to_h)
            else
              subscriber.new.call(event)
            end
          else
            raise ArgumentError, "Invalid subscriber: #{subscriber.inspect}. Must be a Proc, callable, or Spree::Subscriber subclass."
          end
        end

        def handle_subscriber_error(error, event, subscription)
          Rails.error.report(error, context: {
            event_name: event.name,
            subscriber: subscription.subscriber.to_s,
            event_id: event.metadata['event_id']
          })

          # Re-raise in development/test for visibility
          raise if Rails.env.development? || Rails.env.test?
        end
      end
    end
  end
end

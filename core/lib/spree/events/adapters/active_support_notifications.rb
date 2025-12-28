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
      class ActiveSupportNotifications < Base
        NAMESPACE = 'spree'

        def initialize(registry)
          super
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
          event = build_event(event_name, payload, metadata)
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

      end
    end
  end
end

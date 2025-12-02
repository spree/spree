# frozen_string_literal: true

module Spree
  module Events
    module Adapters
      # Base class for event adapters.
      #
      # Adapters are responsible for the actual publishing and subscription
      # management of events. The default adapter uses ActiveSupport::Notifications,
      # but you can create custom adapters for other backends like Kafka, RabbitMQ,
      # or Redis Pub/Sub.
      #
      # @example Creating a custom adapter
      #   class MyApp::Events::KafkaAdapter < Spree::Events::Adapters::Base
      #     def publish(event_name, payload, metadata = {})
      #       event = Spree::Event.new(name: event_name, payload: payload, metadata: metadata)
      #       kafka_producer.produce(event.to_json, topic: event_name)
      #       event
      #     end
      #
      #     def activate!
      #       @kafka_producer = Kafka.new.producer
      #     end
      #
      #     def deactivate!
      #       @kafka_producer&.shutdown
      #     end
      #   end
      #
      # @example Configuring Spree to use your adapter
      #   # config/initializers/spree.rb
      #   Spree.events_adapter_class = 'MyApp::Events::KafkaAdapter'
      #
      class Base
        attr_reader :registry

        # Initialize the adapter with a registry.
        #
        # @param registry [Spree::Events::Registry] the subscription registry
        def initialize(registry)
          @registry = registry
        end

        # Publish an event to all matching subscribers.
        #
        # @param event_name [String] the event name (e.g., 'order.complete')
        # @param payload [Hash] the event payload (should be serializable)
        # @param metadata [Hash] additional metadata for the event
        # @return [Spree::Event] the published event
        #
        # @example
        #   adapter.publish('order.complete', order.serializable_hash, { user_id: 1 })
        #
        def publish(event_name, payload, metadata = {})
          raise NotImplementedError, "#{self.class}#publish must be implemented"
        end

        # Subscribe to an event pattern.
        #
        # This method should register the subscriber in the registry.
        # The adapter is responsible for ensuring events are routed to
        # matching subscribers.
        #
        # @param pattern [String] event pattern (supports wildcards like 'order.*')
        # @param subscriber [Class, Proc] the subscriber class or callable
        # @param options [Hash] subscription options
        # @option options [Boolean] :async (true) whether to run async via ActiveJob
        #
        # @example
        #   adapter.subscribe('order.complete', MySubscriber)
        #   adapter.subscribe('order.*', AuditLogger, async: false)
        #
        def subscribe(pattern, subscriber, options = {})
          raise NotImplementedError, "#{self.class}#subscribe must be implemented"
        end

        # Unsubscribe from an event pattern.
        #
        # @param pattern [String] event pattern
        # @param subscriber [Class, Proc] the subscriber to remove
        # @return [Boolean] true if removed, false if not found
        #
        def unsubscribe(pattern, subscriber)
          raise NotImplementedError, "#{self.class}#unsubscribe must be implemented"
        end

        # Activate the adapter.
        #
        # Called during Rails initialization. Use this to set up connections,
        # start consumers, or perform any initialization needed.
        #
        def activate!
          raise NotImplementedError, "#{self.class}#activate! must be implemented"
        end

        # Deactivate the adapter.
        #
        # Called during shutdown or when resetting the event system.
        # Use this to clean up connections and resources.
        #
        def deactivate!
          raise NotImplementedError, "#{self.class}#deactivate! must be implemented"
        end

        protected

        # Helper to create an event object.
        #
        # @param event_name [String]
        # @param payload [Hash]
        # @param metadata [Hash]
        # @return [Spree::Event]
        def build_event(event_name, payload, metadata)
          Spree::Event.new(
            name: event_name,
            payload: payload,
            metadata: metadata
          )
        end

        # Find and invoke all matching subscribers for an event.
        #
        # Checks if events are enabled and invokes each matching subscriber.
        # Errors are caught and handled via handle_subscriber_error.
        #
        # @param event [Spree::Event] the event to dispatch
        def invoke_subscribers(event)
          return unless Spree::Events.enabled?

          subscriptions = registry.subscriptions_for(event.name)

          subscriptions.each do |subscription|
            invoke_subscriber(subscription.subscriber, event, subscription.options)
          rescue StandardError => e
            handle_subscriber_error(e, event, subscription)
          end
        end

        # Invoke a single subscriber with an event.
        #
        # Handles different subscriber types (Proc, callable, Spree::Subscriber)
        # and async/sync execution via ActiveJob.
        #
        # @param subscriber [Class, Proc, #call] the subscriber
        # @param event [Spree::Event] the event
        # @param options [Hash] subscription options
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

        # Handle errors that occur during subscriber invocation.
        #
        # Reports the error to Rails.error and re-raises in development/test
        # for visibility. In production, the error is swallowed after reporting.
        #
        # @param error [StandardError] the error that occurred
        # @param event [Spree::Event] the event being processed
        # @param subscription [Spree::Events::Registry::Subscription] the subscription
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

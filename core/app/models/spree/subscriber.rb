# frozen_string_literal: true

module Spree
  # Base class for event subscribers.
  #
  # Subscribers handle events published through the Spree event system.
  # They provide a clean DSL for declaring which events to subscribe to
  # and are automatically registered during Rails initialization.
  #
  # @example Basic subscriber
  #   class OrderCompletedNotifier < Spree::Subscriber
  #     subscribes_to 'order.complete'
  #
  #     def call(event)
  #       order_id = event.payload['id']
  #       Spree::OrderMailer.confirm_email(order_id).deliver_later
  #     end
  #   end
  #
  # @example Multi-event subscriber
  #   class OrderAuditLogger < Spree::Subscriber
  #     subscribes_to 'order.complete', 'order.cancel', 'order.resume'
  #
  #     def call(event)
  #       AuditLog.create!(
  #         event_name: event.name,
  #         payload: event.payload,
  #         occurred_at: event.timestamp
  #       )
  #     end
  #   end
  #
  # @example Pattern matching subscriber
  #   class OrderEventLogger < Spree::Subscriber
  #     subscribes_to 'order.*'
  #
  #     def call(event)
  #       Rails.logger.info("Order event: #{event.name}")
  #     end
  #   end
  #
  # @example Subscriber with method routing
  #   class PaymentSubscriber < Spree::Subscriber
  #     subscribes_to 'payment.complete', 'payment.void', 'payment.refund'
  #
  #     on 'payment.complete', :handle_complete
  #     on 'payment.void', :handle_void
  #     on 'payment.refund', :handle_refund
  #
  #     private
  #
  #     def handle_complete(event)
  #       # Handle payment completion
  #     end
  #
  #     def handle_void(event)
  #       # Handle payment void
  #     end
  #
  #     def handle_refund(event)
  #       # Handle payment refund
  #     end
  #   end
  #
  # @example Synchronous subscriber (runs immediately, not via ActiveJob)
  #   class CriticalOrderHandler < Spree::Subscriber
  #     subscribes_to 'order.complete', async: false
  #
  #     def call(event)
  #       # This runs synchronously
  #     end
  #   end
  #
  class Subscriber
    class << self
      # DSL method to declare which events this subscriber handles
      #
      # @param patterns [Array<String>] Event patterns to subscribe to
      # @param options [Hash] Subscription options
      # @option options [Boolean] :async (true) Whether to run async via ActiveJob
      # @return [void]
      #
      # @example
      #   subscribes_to 'order.complete'
      #   subscribes_to 'order.complete', 'order.cancel'
      #   subscribes_to 'order.*'
      #   subscribes_to 'order.complete', async: false
      #
      def subscribes_to(*patterns, **options)
        @subscription_patterns ||= []
        @subscription_options = options

        patterns.flatten.each do |pattern|
          @subscription_patterns << pattern.to_s
        end
      end

      # DSL method to route specific events to specific methods
      #
      # @param pattern [String] Event pattern
      # @param method_name [Symbol] Method to call for this event
      # @return [void]
      #
      # @example
      #   on 'payment.complete', :handle_complete
      #   on 'payment.void', :handle_void
      #
      def on(pattern, method_name)
        @event_handlers ||= {}
        @event_handlers[pattern.to_s] = method_name
      end

      # Get all subscription patterns for this subscriber
      #
      # @return [Array<String>]
      def subscription_patterns
        @subscription_patterns ||= []
      end

      # Get subscription options
      #
      # @return [Hash]
      def subscription_options
        @subscription_options ||= {}
      end

      # Get event handlers mapping
      #
      # @return [Hash<String, Symbol>]
      def event_handlers
        @event_handlers ||= {}
      end

      # Class-level call method for when the class itself is used as subscriber
      #
      # @param event [Spree::Event]
      def call(event)
        new.call(event)
      end
    end

    # Handle an event
    #
    # Override this method in subclasses to handle events.
    # If you've defined event handlers with `on`, this method
    # will route to the appropriate handler automatically.
    #
    # @param event [Spree::Event] The event to handle
    # @return [void]
    def call(event)
      handler = find_handler(event)

      if handler
        send(handler, event)
      else
        # Default behavior - subclasses should override
        handle(event)
      end
    end

    # Default event handler
    #
    # Override this in subclasses if not using the `on` DSL
    #
    # @param event [Spree::Event]
    def handle(event)
      # Override in subclass
    end

    private

    def find_handler(event)
      handlers = self.class.event_handlers

      # Try exact match first
      return handlers[event.name] if handlers.key?(event.name)

      # Try pattern matching
      handlers.each do |pattern, method_name|
        return method_name if event.matches?(pattern)
      end

      nil
    end
  end
end

# frozen_string_literal: true

module Spree
  # Concern for models that publish events.
  #
  # This concern is included in Spree::Base, so all Spree models
  # can emit events. Event payloads are generated using dedicated
  # serializers from the Spree::Events namespace.
  #
  # @example Disabling events for a specific model
  #   class Spree::LogEntry < Spree.base_class
  #     self.publish_events = false
  #   end
  #
  # @example Publishing custom events
  #   class Spree::Order < Spree.base_class
  #     def complete!
  #       # ... completion logic ...
  #       publish_event('order.completed')
  #     end
  #   end
  #
  # @example Creating an event serializer (required for each model that publishes events)
  #   # app/serializers/spree/events/order_serializer.rb
  #   class Spree::Events::OrderSerializer < Spree::Events::BaseSerializer
  #     protected
  #
  #     def attributes
  #       {
  #         id: resource.id,
  #         number: resource.number,
  #         state: resource.state.to_s,
  #         # ... other attributes
  #       }
  #     end
  #   end
  #
  module Publishable
    extend ActiveSupport::Concern

    # Error raised when a model tries to publish an event but has no serializer defined
    class MissingSerializerError < StandardError
      def initialize(model_class)
        serializer_name = "Spree::Events::#{model_class.name.demodulize}Serializer"
        super(
          "Missing event serializer for #{model_class.name}. " \
          "Please create #{serializer_name} that inherits from Spree::Events::BaseSerializer. " \
          "Example:\n\n" \
          "  class #{serializer_name} < Spree::Events::BaseSerializer\n" \
          "    protected\n\n" \
          "    def attributes\n" \
          "      {\n" \
          "        id: resource.id,\n" \
          "        # add other attributes here\n" \
          "        updated_at: timestamp(resource.updated_at)\n" \
          "      }\n" \
          "    end\n" \
          "  end"
        )
      end
    end

    included do
      class_attribute :publish_events, default: true
      class_attribute :lifecycle_events_enabled, default: false
    end

    class_methods do
      # Enable automatic lifecycle event publishing
      #
      # @param options [Hash] Options for lifecycle events
      # @option options [Array<Symbol>] :only Limit to specific events (:create, :update, :destroy)
      # @option options [Array<Symbol>] :except Exclude specific events
      # @return [void]
      #
      # @example
      #   publishes_lifecycle_events
      #   publishes_lifecycle_events only: [:create, :destroy]
      #   publishes_lifecycle_events except: [:update]
      #
      def publishes_lifecycle_events(options = {})
        self.lifecycle_events_enabled = true

        events = [:create, :update, :destroy]
        events &= Array(options[:only]) if options[:only]
        events -= Array(options[:except]) if options[:except]

        if events.include?(:create)
          after_commit :publish_create_event, on: :create, if: :should_publish_events?
        end

        if events.include?(:update)
          after_commit :publish_update_event, on: :update, if: :should_publish_events?
        end

        if events.include?(:destroy)
          before_destroy :capture_pre_destroy_payload, if: :should_publish_events?
          after_commit :publish_destroy_event, on: :destroy, if: :should_publish_events?
        end
      end

      # Disable lifecycle events for this model
      #
      # @example
      #   class Spree::LogEntry < Spree.base_class
      #     skip_lifecycle_events
      #   end
      #
      def skip_lifecycle_events
        self.publish_events = false
      end

      # Get the event name prefix for this model
      #
      # If a parent class has explicitly set an event_prefix, it will be inherited.
      # Otherwise, uses model_name.element (e.g., 'order' for Spree::Order)
      #
      # @return [String] e.g., 'order' for Spree::Order
      def event_prefix
        # If this class has an explicitly set prefix, use it
        return @event_prefix if defined?(@event_prefix) && @event_prefix.present?

        # Check if a parent class has an explicitly set prefix
        parent = superclass
        while parent && parent.respond_to?(:event_prefix)
          if parent.instance_variable_defined?(:@event_prefix) && parent.instance_variable_get(:@event_prefix).present?
            return parent.instance_variable_get(:@event_prefix)
          end
          parent = parent.superclass
        end

        # Default to model_name.element
        @event_prefix ||= model_name.element
      end

      # Set a custom event prefix
      #
      # @param prefix [String]
      def event_prefix=(prefix)
        @event_prefix = prefix
      end
    end

    # Publish an event with this model's data
    #
    # @param event_name [String] The event name (e.g., 'order.complete')
    # @param payload [Hash, nil] Custom payload (defaults to event_payload)
    # @param metadata [Hash] Additional metadata
    # @return [Spree::Event] The published event
    #
    # @example
    #   order.publish_event('order.completed')
    #   order.publish_event('order.completed', { custom: 'data' })
    #   order.publish_event('order.completed', metadata: { user_id: 1 })
    #
    def publish_event(event_name, payload = nil, metadata = {})
      return unless Spree::Events.enabled?

      @_current_event_name = event_name
      payload ||= event_payload
      Spree::Events.publish(event_name, payload, metadata.merge(default_event_metadata))
    ensure
      @_current_event_name = nil
    end

    # Get the payload for events
    #
    # Uses dedicated event serializer (Spree::Events::ModelSerializer).
    # Raises MissingSerializerError if no serializer is defined.
    #
    # @return [Hash]
    # @raise [MissingSerializerError] if no serializer is defined for this model
    def event_payload
      serializer = event_serializer_class

      raise MissingSerializerError, self.class unless serializer

      serializer.serialize(self, event_context)
    end

    # Find the event serializer class for this model
    #
    # Looks for Spree::Events::ModelNameSerializer (e.g., Spree::Events::OrderSerializer)
    # Also walks up the class hierarchy to find a serializer for parent classes.
    # This allows subclasses like Spree::Exports::Products to use ExportSerializer.
    #
    # @return [Class, nil] The serializer class or nil if not found
    def event_serializer_class
      return nil unless self.class.name

      # Try this class and walk up the hierarchy
      klass = self.class
      while klass && klass != Object && klass != BasicObject
        class_name = klass.name&.demodulize
        # Skip looking for BaseSerializer - that's the parent class for all serializers
        if class_name.present? && class_name != 'Base'
          serializer = "Spree::Events::#{class_name}Serializer".safe_constantize
          return serializer if serializer
        end

        klass = klass.superclass
      end

      nil
    end

    # Context passed to the event serializer
    #
    # @return [Hash]
    def event_context
      {
        event_name: @_current_event_name,
        triggered_at: Time.current
      }
    end

    # Get the event prefix for this instance
    #
    # @return [String]
    def event_prefix
      self.class.event_prefix
    end

    private

    def should_publish_events?
      self.class.publish_events && Spree::Events.enabled?
    end

    def default_event_metadata
      {
        model_class: self.class.name,
        model_id: try(:id)
      }
    end

    def publish_create_event
      publish_event("#{event_prefix}.created")
    end

    def publish_update_event
      publish_event("#{event_prefix}.updated")
    end

    def publish_destroy_event
      # For destroy, we need to capture the data before it's gone
      # The after_commit runs after the record is deleted, so we use
      # the previously captured payload
      publish_event("#{event_prefix}.destroyed", @_pre_destroy_payload || event_payload)
    end

    def capture_pre_destroy_payload
      @_pre_destroy_payload = event_payload
    end
  end
end

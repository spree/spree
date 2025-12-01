# frozen_string_literal: true

module Spree
  # Concern for models that publish events.
  #
  # This concern is included in Spree::Base, so all Spree models
  # automatically emit lifecycle events (create, update, destroy).
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
  #       publish_event('order.complete')
  #     end
  #   end
  #
  # @example With custom serialization
  #   class Spree::Order < Spree.base_class
  #     def event_payload
  #       serializable_hash(
  #         only: [:id, :number, :state, :total],
  #         include: { line_items: { only: [:id, :quantity] } }
  #       )
  #     end
  #   end
  #
  module Publishable
    extend ActiveSupport::Concern

    included do
      class_attribute :publish_events, default: true
      class_attribute :lifecycle_events_enabled, default: false
      class_attribute :event_serialization_options, default: {}
    end

    class_methods do
      # Enable automatic lifecycle event publishing
      #
      # @param options [Hash] Options for lifecycle events
      # @option options [Array<Symbol>] :only Limit to specific events (:create, :update, :destroy)
      # @option options [Array<Symbol>] :except Exclude specific events
      # @option options [Hash] :serialize Options passed to serializable_hash
      # @return [void]
      #
      # @example
      #   publishes_lifecycle_events
      #   publishes_lifecycle_events only: [:create, :destroy]
      #   publishes_lifecycle_events except: [:update]
      #   publishes_lifecycle_events serialize: { only: [:id, :name] }
      #
      def publishes_lifecycle_events(options = {})
        self.lifecycle_events_enabled = true
        self.event_serialization_options = options.fetch(:serialize, {})

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
      # @return [String] e.g., 'order' for Spree::Order
      def event_prefix
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
    #   order.publish_event('order.complete')
    #   order.publish_event('order.complete', { custom: 'data' })
    #   order.publish_event('order.complete', metadata: { user_id: 1 })
    #
    def publish_event(event_name, payload = nil, metadata = {})
      return unless Spree::Events.enabled?

      payload ||= event_payload
      Spree::Events.publish(event_name, payload, metadata.merge(default_event_metadata))
    end

    # Get the payload for events
    #
    # Override this method to customize the data sent with events.
    # By default, uses ActiveModel::Serialization#serializable_hash.
    #
    # @return [Hash]
    def event_payload
      options = self.class.event_serialization_options.presence || default_serialization_options
      serializable_hash(options)
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

    def default_serialization_options
      {}
    end

    def default_event_metadata
      {
        model_class: self.class.name,
        model_id: try(:id)
      }
    end

    def publish_create_event
      publish_event("#{event_prefix}.create")
    end

    def publish_update_event
      publish_event("#{event_prefix}.update")
    end

    def publish_destroy_event
      # For destroy, we need to capture the data before it's gone
      # The after_commit runs after the record is deleted, so we use
      # the previously captured payload
      publish_event("#{event_prefix}.destroy", @_pre_destroy_payload || event_payload)
    end

    def capture_pre_destroy_payload
      @_pre_destroy_payload = event_payload
    end
  end
end

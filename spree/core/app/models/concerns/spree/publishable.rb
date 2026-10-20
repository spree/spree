# frozen_string_literal: true

module Spree
  # Concern for models that publish events.
  #
  # This concern is included in Spree::Base, so all Spree models
  # can emit events. Event payloads are generated using V3 API serializers
  # resolved by convention: Spree::Order → Spree::Api::V3::OrderSerializer.
  #
  # Models without a V3 serializer get a minimal fallback payload:
  #   { id: prefixed_id, created_at: ..., updated_at: ... }
  #
  # STI models (e.g., Spree::Exports::Products) can override
  # event_serializer_class to point to the parent serializer.
  #
  # @example Disabling events for a specific model
  #   class Spree::StockMovement < Spree.base_class
  #     self.publish_events = false
  #   end
  #
  # @example Publishing custom events
  #   class Spree::Order < Spree.base_class
  #     def complete!
  #       # ... completion logic ...
  #       publish_event('order.placed')
  #     end
  #   end
  #
  # @example Overriding the serializer for STI models
  #   class Spree::Export < Spree.base_class
  #     def event_serializer_class
  #       Spree::Api::V3::ExportSerializer
  #     end
  #   end
  #
  module Publishable
    extend ActiveSupport::Concern

    LIFECYCLE_ACTIONS = { create: :created, update: :updated, delete: :deleted }.freeze

    included do
      class_attribute :publish_events, default: true
      class_attribute :lifecycle_events_enabled, default: false
      class_attribute :lifecycle_event_actions, default: []

      after_update :mark_real_update_for_events
    end

    # A bare `touch` (variant → product, price → variant, asset → variants)
    # writes no attribute changes — the resulting update event would carry
    # nothing subscribers haven't already been told. Track it here so the
    # commit callback can tell a touch-only commit from a real update;
    # `saved_changes` can't (a touch replays the previous save's changeset).
    def touch(*names, time: nil)
      @_spree_touched_for_events = true
      super
    end

    class_methods do
      # Enable automatic lifecycle event publishing
      #
      # @param options [Hash] Options for lifecycle events
      # @option options [Array<Symbol>] :only Limit to specific events (:create, :update, :delete)
      # @option options [Array<Symbol>] :except Exclude specific events
      # @return [void]
      #
      # @example
      #   publishes_lifecycle_events
      #   publishes_lifecycle_events only: [:create, :delete]
      #   publishes_lifecycle_events except: [:update]
      #
      def publishes_lifecycle_events(options = {})
        # Guard against duplicate callback registration (important for code reload in development)
        return if lifecycle_events_enabled

        self.lifecycle_events_enabled = true

        events = [:create, :update, :delete]
        events &= Array(options[:only]) if options[:only]
        events -= Array(options[:except]) if options[:except]

        self.lifecycle_event_actions = events.map { |event| LIFECYCLE_ACTIONS.fetch(event) }
        lifecycle_event_actions.each { |action| publishes_event(action) }

        if events.include?(:create)
          after_commit :publish_create_event, on: :create, if: :should_publish_events?
        end

        if events.include?(:update)
          after_commit :publish_update_event, on: :update, if: :should_publish_events?
        end

        if events.include?(:delete)
          before_destroy :capture_pre_destroy_payload, if: :should_publish_events?
          after_commit :publish_delete_event, on: :destroy, if: :should_publish_events?
        end
      end

      # A subclass publishes its lifecycle events under its own prefix, which may
      # differ from its parent's, so they are declared again for it.
      def inherited(subclass)
        super
        subclass.lifecycle_event_actions.each { |action| subclass.publishes_event(action) }
      end

      # Declare events this model publishes, each carrying this model's Store
      # serializer as its payload.
      #
      # @param names [Array<Symbol, String>] actions (`:placed`, prefixed with
      #   {event_prefix}) or full dotted names (`'customer.password_reset'`)
      # @param options [Hash] see {publishes_event}
      # @return [void]
      #
      # @example
      #   publishes_events :placed, :paid, :shipped
      def publishes_events(*names, **options)
        names.each { |name| publishes_event(name, **options) }
      end

      # Declare one event this model publishes. Publishing a name no model
      # declared raises in development and test.
      #
      # @param name [Symbol, String] an action or a full dotted name
      # @param serializer [String, nil] payload serializer class name, when the
      #   payload is not this model's Store serializer
      # @param credential [String, nil] for a payload carrying a live credential,
      #   the permission key needed to point a webhook endpoint at it; such an
      #   event reaches only endpoints that name it outright
      # @param deprecated_alias_of [String, nil] the event this one duplicates
      # @param webhook [Boolean] false for an event no webhook endpoint may
      #   receive, even one subscribed to `*`
      # @return [void]
      #
      # @example
      #   publishes_event :canceled, serializer: 'Spree::Api::V3::OrderCanceledEventSerializer'
      #   publishes_event 'customer.password_reset_requested', serializer: '...', credential: 'write_customers'
      def publishes_event(name, serializer: nil, credential: nil, deprecated_alias_of: nil, webhook: true)
        Spree::Events.catalog.declare(
          self, name,
          serializer: serializer, credential: credential, deprecated_alias_of: deprecated_alias_of, webhook: webhook
        )
      end

      # Disable lifecycle events for this model
      #
      # @example
      #   class Spree::StockMovement < Spree.base_class
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
    # @param event_name [String] The event name (e.g., 'order.placed')
    # @param payload [Hash, nil] Custom payload (defaults to event_payload)
    # @param metadata [Hash] Additional metadata
    # @return [Spree::Event] The published event
    #
    # @example
    #   order.publish_event('order.placed')
    #   order.publish_event('order.placed', { custom: 'data' })
    #   order.publish_event('order.placed', metadata: { user_id: 1 })
    #
    def publish_event(event_name, payload = nil, metadata = {})
      # Checked even while events are disabled, so every spec that reaches a
      # publish also proves the event is declared.
      Spree::Events.catalog.verify_declared!(event_name)
      return unless Spree::Events.enabled?

      @_current_event_name = event_name
      payload ||= event_payload_for(event_name)
      Spree::Events.publish(event_name, payload, metadata)
    ensure
      @_current_event_name = nil
    end

    # Get the payload for events
    #
    # Uses the V3 serializer resolved by convention.
    # Falls back to a minimal payload if no serializer is found.
    #
    # @return [Hash]
    def event_payload
      build_event_payload(event_serializer_class)
    end

    # The payload for one event, built with the serializer the catalog declares
    # for it, falling back to this model's Store serializer.
    #
    # @param event_name [String]
    # @param params [Hash] extra serializer params the event serializer reads,
    #   e.g. the reset token of a password reset request
    # @return [Hash]
    def event_payload_for(event_name, **params)
      serializer = Spree::Events.catalog.find(event_name)&.serializer_name&.safe_constantize
      build_event_payload(serializer || event_serializer_class, params)
    end

    # Find the event serializer class for this model
    #
    # Looks for Spree::Api::V3::ModelNameSerializer by convention.
    # Walks up the class hierarchy to support STI models.
    #
    # Models can override this method to specify a custom serializer,
    # which is useful for STI models like Export, Import, Report.
    #
    # @return [Class, nil] The serializer class or nil if not found
    def event_serializer_class
      return nil unless self.class.name

      klass = self.class
      while klass && klass != Object && klass != BasicObject
        class_name = klass.name&.demodulize
        if class_name.present? && class_name != 'Base'
          serializer = "Spree::Api::V3::#{class_name}Serializer".safe_constantize
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
        store_id: Spree::Current.store&.id,
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

    def build_event_payload(serializer, params = {})
      unless serializer
        return {
          id: respond_to?(:prefixed_id) ? prefixed_id : id,
          created_at: created_at&.iso8601,
          updated_at: updated_at&.iso8601
        }
      end

      # Use as_json to ensure all values are JSON-safe primitives.
      # Alba's to_h can return raw Ruby objects (e.g., Spree::Money) which
      # ActiveJob cannot serialize for async event subscribers.
      serializer.new(self, params: event_serializer_params.merge(params)).to_h.as_json
    end

    # Build params for V3 serializers
    #
    # @return [Hash]
    def event_serializer_params
      store = respond_to?(:store) ? self.store : nil
      store ||= Spree::Current.store

      {
        store: store,
        currency: Spree::Current.currency,
        user: nil,
        locale: nil,
        includes: []
      }
    end

    def should_publish_events?
      self.class.publish_events && Spree::Events.lifecycle_enabled?
    end

    # True when this commit was caused only by `touch` — no real save ran
    # (`after_update` fires for saves, never for touches). Flags reset every
    # commit so a later genuine update publishes normally.
    def touch_only_update?
      touched = @_spree_touched_for_events
      updated = @_spree_updated_for_events
      @_spree_touched_for_events = @_spree_updated_for_events = nil
      touched && !updated
    end

    def mark_real_update_for_events
      @_spree_updated_for_events = true
    end

    def publish_create_event
      publish_event("#{event_prefix}.created")
    end

    def publish_update_event
      return if touch_only_update?

      publish_event("#{event_prefix}.updated")
    end

    def publish_delete_event
      # For delete, we need to capture the data before it's gone
      # The after_commit runs after the record is deleted, so we use
      # the previously captured payload
      publish_event("#{event_prefix}.deleted", @_pre_destroy_payload || event_payload)
    end

    def capture_pre_destroy_payload
      @_pre_destroy_payload = event_payload
    end
  end
end

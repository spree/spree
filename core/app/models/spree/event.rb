# frozen_string_literal: true

module Spree
  # Represents an event in the Spree event system.
  #
  # Events are immutable objects that carry information about something
  # that happened in the system. They contain:
  # - A name (e.g., 'order.complete', 'product.create')
  # - A payload (serialized data about the event)
  # - Metadata (contextual information like store_id, timestamps)
  #
  # @example Creating an event
  #   event = Spree::Event.new(
  #     name: 'order.complete',
  #     payload: order.serializable_hash
  #   )
  #
  # @example Accessing event data
  #   event.name      # => 'order.complete'
  #   event.payload   # => { 'id' => 1, 'number' => 'R123456' }
  #   event.timestamp # => 2024-01-15 10:30:00 UTC
  #
  class Event
    attr_reader :name, :payload, :metadata, :timestamp

    # @param name [String] The event name (e.g., 'order.complete')
    # @param payload [Hash] The serialized event data
    # @param metadata [Hash] Additional contextual information
    def initialize(name:, payload:, metadata: {})
      @name = name.to_s.freeze
      @payload = (payload || {}).deep_stringify_keys.freeze
      @timestamp = Time.current.freeze
      @metadata = build_metadata(metadata).freeze
    end

    # Returns the resource type from the event name
    # @return [String] The resource type (e.g., 'order' from 'order.complete')
    def resource_type
      @resource_type ||= name.split('.').first
    end

    # Returns the action from the event name
    # @return [String] The action (e.g., 'complete' from 'order.complete')
    def action
      @action ||= name.split('.').drop(1).join('.')
    end

    # Checks if the event matches a pattern
    # Supports wildcards: 'order.*' matches 'order.complete', 'order.cancel'
    # @param pattern [String] The pattern to match against
    # @return [Boolean]
    def matches?(pattern)
      self.class.matches?(name, pattern)
    end

    # Class method to check if an event name matches a pattern
    # @param event_name [String] The event name
    # @param pattern [String] The pattern (supports * wildcard)
    # @return [Boolean]
    def self.matches?(event_name, pattern)
      return true if pattern == '*'

      if pattern.include?('*')
        regex = Regexp.new("^#{Regexp.escape(pattern).gsub('\*', '.*')}$")
        event_name.match?(regex)
      else
        event_name == pattern
      end
    end

    # Convert to hash representation
    # @return [Hash]
    def to_h
      {
        name: name,
        payload: payload,
        metadata: metadata,
        timestamp: timestamp
      }
    end

    def inspect
      "#<Spree::Event name=#{name.inspect} timestamp=#{timestamp.iso8601}>"
    end

    private

    def build_metadata(custom_metadata)
      base_metadata = {
        'event_id' => SecureRandom.uuid,
        'timestamp' => @timestamp.iso8601,
        'spree_version' => Spree.version
      }

      # Add store context if available
      if defined?(Spree::Store) && Spree::Store.respond_to?(:current)
        current_store = Spree::Store.current
        base_metadata['store_id'] = current_store&.id&.to_s
      end

      # Add request context if available (via CurrentAttributes or similar)
      if defined?(Current) && Current.respond_to?(:request_id)
        base_metadata['request_id'] = Current.request_id
      end

      # Merge custom metadata and ensure IDs are strings for JSON consistency
      merged = base_metadata.merge(stringify_metadata(custom_metadata))
      merged
    end

    def stringify_metadata(hash)
      hash.deep_stringify_keys.transform_values do |value|
        case value
        when Integer, BigDecimal
          value.to_s
        when Hash
          stringify_metadata(value)
        when Array
          value.map { |v| v.is_a?(Hash) ? stringify_metadata(v) : v }
        else
          value
        end
      end
    end
  end
end

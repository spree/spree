# frozen_string_literal: true

module Spree
  # Represents an event in the Spree event system.
  #
  # Events are immutable objects that carry information about something
  # that happened in the system. They contain:
  # - An id (UUID)
  # - A name (e.g., 'order.complete', 'product.create')
  # - A store_id (the store where the event originated)
  # - A payload (serialized data about the event)
  # - Metadata (contextual information like spree_version)
  #
  # @example Creating an event
  #   event = Spree::Event.new(
  #     name: 'order.complete',
  #     payload: order.serializable_hash
  #   )
  #
  # @example Accessing event data
  #   event.id         # => "550e8400-e29b-41d4-a716-446655440000"
  #   event.name       # => 'order.complete'
  #   event.store_id   # => 1
  #   event.payload    # => { 'id' => 1, 'number' => 'R123456' }
  #   event.created_at # => 2024-01-15 10:30:00 UTC
  #
  class Event
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Attributes::Normalization
    include ActiveModel::Serializers::JSON

    attribute :id, :string, default: -> { SecureRandom.uuid }
    attribute :name, :string
    attribute :store_id, :integer, default: -> { Spree::Current.store&.id }
    attribute :payload, default: -> { {}.freeze }
    attribute :metadata, default: -> { { 'spree_version' => Spree.version }.freeze }
    attribute :created_at, :datetime, default: -> { Time.current }

    validates :name, presence: true
    validates :store_id, presence: true

    normalizes :name, with: ->(value) { value.to_s.freeze }
    normalizes :payload, with: ->(value) { (value || {}).deep_stringify_keys.freeze }
    normalizes :metadata, with: ->(value) {
      base = { 'spree_version' => Spree.version }
      base.merge((value || {}).deep_stringify_keys).freeze
    }

    # Returns the store where the event originated
    # @return [Spree::Store, nil]
    def store
      return nil if store_id.blank?

      @store ||= Spree::Store.find_by(id: store_id)
    end

    # Returns the resource type from the event name
    # @return [String] The resource type (e.g., 'order' from 'order.complete')
    def resource_type
      @resource_type ||= name.to_s.split('.').first
    end

    # Returns the action from the event name
    # @return [String] The action (e.g., 'complete' from 'order.complete')
    def action
      @action ||= name.to_s.split('.').drop(1).join('.')
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

    alias_method :to_h, :attributes

    def inspect
      "#<Spree::Event id=#{id.inspect} name=#{name.inspect} store_id=#{store_id.inspect} created_at=#{created_at&.iso8601}>"
    end
  end
end

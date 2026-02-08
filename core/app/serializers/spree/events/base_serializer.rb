# frozen_string_literal: true

module Spree
  module Events
    class BaseSerializer
      attr_reader :resource, :context

      def initialize(resource, context = {})
        @resource = resource
        @context = context
      end

      # Main serialization method
      def as_json
        attributes
      end

      # Class method for convenience
      def self.serialize(resource, context = {})
        new(resource, context).as_json
      end

      protected

      # Override in subclasses to define attributes
      def attributes
        {
          id: resource.prefix_id
        }
      end

      # Context helpers
      def event_name
        context[:event_name]
      end

      def triggered_at
        context[:triggered_at] || Time.current
      end

      # Resolve a belongs_to association's prefix_id
      # @param association_name [Symbol] the association name (e.g., :product, :order)
      # @return [String, nil] the prefix_id of the associated record
      def association_prefix_id(association_name)
        resource.public_send(association_name)&.prefix_id
      end

      # Attribute helpers

      # Safely get attribute, returns nil if not present
      def attribute(name)
        resource.public_send(name) if resource.respond_to?(name)
      end

      # Timestamp helper - ISO8601 format
      def timestamp(time)
        time&.iso8601
      end

      # Money helper - decimal value for events
      def money(amount)
        return nil if amount.nil?

        amount.respond_to?(:to_d) ? amount.to_d : amount
      end
    end
  end
end

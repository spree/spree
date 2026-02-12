# frozen_string_literal: true

require 'sqids'

module Spree
  # Adds Stripe-style prefixed IDs to Spree models using Sqids encoding.
  # IDs are computed on the fly from integer primary keys — no database column needed.
  #
  # e.g., Product with id=12345 → "prod_86Rf07xd4z"
  #
  # Usage in models:
  #   class Product < Spree.base_class
  #     has_prefix_id :prod
  #   end
  module PrefixedId
    extend ActiveSupport::Concern

    SQIDS = Sqids.new(min_length: 10)

    # Registry mapping prefix strings to model classes
    # e.g., { "prod" => Spree::Product, "or" => Spree::Order }
    mattr_accessor :prefix_registry, default: {}

    included do
      class_attribute :_prefix_id_prefix, instance_writer: false
    end

    # Returns the Stripe-style prefixed ID for this record.
    # Returns nil for unsaved records (no id yet).
    def prefixed_id
      return nil unless id.present?

      "#{self.class._prefix_id_prefix}_#{SQIDS.encode([id])}"
    end

    # Use prefixed_id for URL params when available.
    # Skip if FriendlyId is used (it has its own to_param using slug).
    def to_param
      return super if self.class.respond_to?(:friendly_id_config)
      return super unless self.class._prefix_id_prefix.present?

      prefixed_id.presence || super
    end

    class_methods do
      def has_prefix_id(prefix)
        self._prefix_id_prefix = prefix.to_s
        Spree::PrefixedId.prefix_registry[prefix.to_s] = self
      end

      # Decode a prefixed ID string and find the record.
      # Works on scopes/relations since `find` respects scope.
      # @param prefixed_id [String] e.g., "prod_86Rf07xd4z"
      # @return [ActiveRecord::Base]
      # @raise [ActiveRecord::RecordNotFound]
      def find_by_prefix_id!(prefixed_id)
        decoded = decode_prefixed_id(prefixed_id)
        raise ActiveRecord::RecordNotFound.new("Couldn't find #{name} with prefixed id=#{prefixed_id}") unless decoded

        find(decoded)
      end

      # Decode a prefixed ID string and find the record, returning nil if not found.
      # @param prefixed_id [String] e.g., "prod_86Rf07xd4z"
      # @return [ActiveRecord::Base, nil]
      def find_by_prefix_id(prefixed_id)
        decoded = decode_prefixed_id(prefixed_id)
        return nil unless decoded

        find_by(id: decoded)
      end

      # Decode a prefixed ID string to the integer primary key.
      # @param prefixed_id_string [String] e.g., "prod_86Rf07xd4z"
      # @return [Integer, nil] the decoded integer ID, or nil if invalid
      def decode_prefixed_id(prefixed_id_string)
        return nil if prefixed_id_string.blank?

        parts = prefixed_id_string.to_s.split('_', 2)
        return nil if parts.length != 2

        _prefix, encoded = parts
        ids = Spree::PrefixedId::SQIDS.decode(encoded)
        ids.first
      end

      def prefix_id_prefix
        _prefix_id_prefix
      end

      # Find a record by prefixed ID first, falling back to integer id for backwards compatibility.
      # @param param [String] the prefixed ID or integer id to search for
      # @return [ActiveRecord::Base, nil]
      def find_by_param(param)
        return nil if param.blank?

        # Try prefixed ID first (new format)
        if param.to_s.include?('_')
          decoded = decode_prefixed_id(param)
          record = find_by(id: decoded) if decoded
          return record if record
        end

        # Fall back to id (legacy format) - only if param looks like an integer
        find_by(id: param) if param.to_s.match?(/\A\d+\z/)
      end

      # Find a record by prefixed ID first, falling back to integer id for backwards compatibility.
      # Raises ActiveRecord::RecordNotFound if not found.
      # @param param [String] the prefixed ID or integer id to search for
      # @return [ActiveRecord::Base]
      # @raise [ActiveRecord::RecordNotFound]
      def find_by_param!(param)
        find_by_param(param) || raise(ActiveRecord::RecordNotFound.new("Couldn't find #{name} with param=#{param}"))
      end

      # Look up the model class for a given prefix string.
      # @param prefix [String] e.g., "prod"
      # @return [Class, nil]
      def model_for_prefix(prefix)
        Spree::PrefixedId.prefix_registry[prefix.to_s]
      end
    end
  end
end

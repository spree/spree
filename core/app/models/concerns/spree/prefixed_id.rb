# frozen_string_literal: true

module Spree
  # Adds Stripe-style prefixed IDs to Spree models
  # e.g., prod_abc123, order_xyz789, var_def456
  #
  # Usage in models:
  #   class Product < Spree.base_class
  #     has_prefix_id :prod
  #   end
  #
  # This stores a prefix_id column in the database (e.g., "prod_abc123")
  # that can be used as the primary identifier in API v3.
  #
  # The prefix_id is auto-generated on record creation and is immutable.
  module PrefixedId
    extend ActiveSupport::Concern

    ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.freeze
    ID_LENGTH = 24

    included do
      class_attribute :_prefix_id_prefix, instance_writer: false
    end

    # Clear prefix_id when duplicating records so a new one is generated
    def initialize_dup(other)
      super
      self.prefix_id = nil if respond_to?(:prefix_id=)
    end

    # Use prefix_id for URL params when available
    # Skip if FriendlyId is used (it has its own to_param using slug)
    # Skip if model doesn't have the prefix_id column
    def to_param
      return super if self.class.respond_to?(:friendly_id_config)
      return super unless self.class.column_names.include?('prefix_id')
      prefix_id.presence || super
    end

    class_methods do
      def has_prefix_id(prefix)
        self._prefix_id_prefix = prefix.to_s

        before_create :generate_prefix_id, if: -> { prefix_id.blank? }

        validates :prefix_id, uniqueness: true, allow_nil: true

        # Class method to find by prefix_id
        scope :find_by_prefix_id, ->(id) { find_by(prefix_id: id) }
      end

      def find_by_prefix_id!(id)
        find_by!(prefix_id: id)
      end

      def prefix_id_prefix
        _prefix_id_prefix
      end
    end

    def generate_prefix_id
      self.prefix_id = "#{self.class._prefix_id_prefix}_#{random_id}"
    end

    private

    def random_id
      Array.new(ID_LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.length)] }.join
    end
  end
end

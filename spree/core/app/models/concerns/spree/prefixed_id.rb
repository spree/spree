# frozen_string_literal: true

require 'sqids'

module Spree
  # Adds Stripe-style prefixed IDs to Spree models using Sqids encoding.
  # IDs are computed on the fly from integer primary keys -- no database column needed.
  #
  # e.g., Product with id=12345 -> "prod_86Rf07xd4z"
  #
  #   class Product < Spree.base_class
  #     has_prefix_id :prod
  #   end
  module PrefixedId
    extend ActiveSupport::Concern

    SQIDS = Sqids.new(min_length: 10)

    included do
      class_attribute :_prefix_id_prefix, instance_writer: false
    end

    # Automatically resolve prefixed ID strings for belongs_to foreign keys.
    # e.g., product.assign_attributes(tax_category_id: "tc_86Rf07xd4z") will
    # decode the prefixed ID to the integer primary key.
    def assign_attributes(new_attributes)
      return super if new_attributes.blank?

      attrs = new_attributes.to_h
      needs_resolution = attrs.any? do |key, value|
        key_s = key.to_s
        (value.is_a?(String) && key_s.end_with?('_id') && Spree::PrefixedId.prefixed_id?(value)) ||
          (value.is_a?(Array) && key_s.end_with?('_ids') && value.any? { |v| Spree::PrefixedId.prefixed_id?(v) })
      end

      return super unless needs_resolution

      resolved = attrs.each_with_object({}.with_indifferent_access) do |(key, value), hash|
        key_s = key.to_s
        if value.is_a?(String) && key_s.end_with?('_id') && Spree::PrefixedId.prefixed_id?(value)
          hash[key] = self.class.resolve_prefixed_id_for_attribute(key_s, value)
        elsif value.is_a?(Array) && key_s.end_with?('_ids')
          hash[key] = self.class.resolve_prefixed_ids_for_attribute(key_s, value)
        else
          hash[key] = value
        end
      end

      super(resolved)
    end

    # Returns the Stripe-style prefixed ID, or nil for unsaved records.
    def prefixed_id
      return nil unless id.present?

      "#{self.class._prefix_id_prefix}_#{Spree::PrefixedId::SQIDS.encode([id])}"
    end

    # Use prefixed_id for URL params when available.
    # Skip if FriendlyId is used (it has its own to_param using slug).
    def to_param
      return super if self.class.respond_to?(:friendly_id_config)
      return super unless self.class._prefix_id_prefix.present?

      prefixed_id.presence || super
    end

    # Module-level methods for use without a model context (e.g., from ParamsNormalizer)
    def self.prefixed_id?(value)
      value.is_a?(String) && value.match?(/\A[a-z]+_[a-zA-Z0-9]+\z/)
    end

    def self.decode_prefixed_id(prefixed_id_string)
      return nil if prefixed_id_string.blank?

      parts = prefixed_id_string.to_s.split('_', 2)
      return nil if parts.length != 2

      _prefix, encoded = parts
      ids = SQIDS.decode(encoded)
      ids.first
    end

    class_methods do
      def has_prefix_id(prefix)
        self._prefix_id_prefix = prefix.to_s
      end

      def prefixed_id?(value)
        Spree::PrefixedId.prefixed_id?(value)
      end

      # Memoized map of foreign_key → belongs_to reflection for prefixed ID resolution.
      def belongs_to_reflections_by_fk
        @belongs_to_reflections_by_fk ||= reflect_on_all_associations(:belongs_to)
          .reject(&:polymorphic?)
          .index_by { |a| a.foreign_key.to_s }
      end

      # Resolve a prefixed ID string for a belongs_to foreign key attribute.
      # Uses the association's target class to validate the record exists.
      def resolve_prefixed_id_for_attribute(attribute_name, prefixed_id_value)
        reflection = belongs_to_reflections_by_fk[attribute_name]

        if reflection
          reflection.klass.find_by_param!(prefixed_id_value).id
        else
          Spree::PrefixedId.decode_prefixed_id(prefixed_id_value) || prefixed_id_value
        end
      end

      # Resolve an array of prefixed IDs for a has_many _ids setter.
      # Infers the target class from the association name (e.g., taxon_ids → taxons → Spree::Taxon).
      def resolve_prefixed_ids_for_attribute(attribute_name, values)
        association_name = attribute_name.sub(/_ids$/, '').pluralize
        reflection = reflect_on_association(association_name.to_sym)
        klass = reflection&.klass

        values.map do |v|
          if Spree::PrefixedId.prefixed_id?(v)
            klass ? klass.find_by_param!(v).id : (Spree::PrefixedId.decode_prefixed_id(v) || v)
          else
            v
          end
        end
      end

      def find_by_prefix_id!(prefixed_id)
        decoded = Spree::PrefixedId.decode_prefixed_id(prefixed_id)
        raise ActiveRecord::RecordNotFound.new("Couldn't find #{name} with prefixed id=#{prefixed_id}", name) unless decoded

        find(decoded)
      end

      def find_by_prefix_id(prefixed_id)
        decoded = Spree::PrefixedId.decode_prefixed_id(prefixed_id)
        return nil unless decoded

        find_by(id: decoded)
      end

      def decode_prefixed_id(prefixed_id_string)
        Spree::PrefixedId.decode_prefixed_id(prefixed_id_string)
      end

      # Find by prefixed ID first, falling back to integer id for backwards compatibility.
      def find_by_param(param)
        return nil if param.blank?

        find_by_prefix_id(param) || (find_by(id: param) if param.to_s.match?(/\A\d+\z/))
      end

      def find_by_param!(param)
        find_by_param(param) || raise(ActiveRecord::RecordNotFound.new("Couldn't find #{name} with param=#{param}", name))
      end
    end
  end
end

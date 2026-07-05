# frozen_string_literal: true

module Spree
  module Preferences
    # Masks `:password`-typed preferences so secrets (API keys, OAuth
    # tokens, signing secrets, …) never leave the server in plaintext.
    #
    # The mask token is a bullet sequence followed by the last 4
    # characters of the original value — Stripe's "stored, here's the
    # last 4" pattern.
    module Masking
      TOKEN = '••••'

      # @param value [Object] the preference value to mask
      # @return [String, nil] masked string, or nil if value is blank
      def self.mask(value)
        return nil if value.blank?

        "#{TOKEN}#{value.to_s.last(4)}"
      end

      # @param value [Object] a value previously returned by `mask`
      # @return [Boolean] true if value carries the mask token
      def self.masked?(value)
        value.is_a?(String) && value.start_with?(TOKEN)
      end

      # Serializes a Preferable's `preferences` hash for the wire,
      # masking `:password` values. Keys are stringified to match the
      # wire shape expected by JSON clients — schema entries built by
      # `compute_preference_schema` cache `:key_string` to avoid a
      # `to_s` allocation per field per request.
      #
      # @param preferable [#preferences, #preference_schema, nil] any object
      #   that includes `Spree::Preferences::Preferable` and `Spree::PreferenceSchema`
      # @return [Hash{String => Object}]
      def self.serialize(preferable)
        return {} if preferable.nil?

        preferable.preference_schema.each_with_object({}) do |field, hash|
          value = preferable.preferences[field[:key]]
          hash[field[:key_string] || field[:key].to_s] = field[:type] == :password ? mask(value) : value
        end
      end
    end
  end
end

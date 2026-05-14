# frozen_string_literal: true

module Spree
  module Preferences
    # Masks `:password`-typed preferences so secrets (API keys, OAuth
    # tokens, signing secrets, …) never leave the server in plaintext.
    #
    # Used by:
    # - `Spree::PreferenceSchema#serializer_preferences` — every admin
    #   serializer exposing a `preferences` attribute routes through it.
    # - `Spree::Api::V3::Admin::SubclassedResource#apply_preferences`,
    #   which uses `masked?` to detect a round-trip of the masked value
    #   back from the client and preserve the existing secret.
    #
    # The mask token is a sequence of bullet characters followed by the
    # last 4 characters of the original value, matching the Stripe-style
    # "stored — show me the last 4" pattern. The same token is also used
    # to redact `default` values for `:password` entries in
    # `preference_schema` payloads.
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
      # masking `:password`-typed values and stringifying keys so the
      # output matches what JSON consumers expect.
      #
      # @param preferable [#preferences, nil] any object that includes
      #   `Spree::Preferences::Preferable` and `Spree::PreferenceSchema`
      # @return [Hash{String => Object}]
      def self.serialize(preferable)
        return {} unless preferable.respond_to?(:preferences) && preferable.class.respond_to?(:preference_schema)

        preferable.class.preference_schema.each_with_object({}) do |field, hash|
          key = field[:key]
          value = preferable.preferences[key]
          hash[key.to_s] = field[:type] == :password ? mask(value) : value
        end
      end

      # Returns a `preference_schema` payload with `:password` defaults
      # redacted. A gateway author can set a non-empty default for a
      # `:password` preference; without this guard, the default leaks
      # through the schema even though the live `preferences` hash is
      # masked.
      #
      # @param schema [Array<Hash>] result of `Klass.preference_schema`
      # @return [Array<Hash>]
      def self.schema(schema)
        return [] unless schema

        schema.map do |field|
          next field unless field[:type] == :password

          field.merge(default: nil)
        end
      end
    end
  end
end

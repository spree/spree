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
      TOKEN_CHARACTER = '•'.freeze
      VISIBLE_CHARACTERS = 4

      # Kept for the round-trip guard: any masked value starts with at least
      # this run of dots, so `masked?` still recognizes what it sent.
      TOKEN = TOKEN_CHARACTER * VISIBLE_CHARACTERS

      # Upper bound on the dots, so a long key stays readable in a form
      # field and the rendered length stops disclosing the exact size of
      # anything longer than this.
      MAX_MASK_LENGTH = 16

      # Masks all but the last four characters, keeping one dot per hidden
      # character so the field reads like the credential it stands for.
      # Values of four characters or fewer are hidden entirely — showing
      # "the last four" of a five-character secret would expose most of it.
      #
      # @param value [Object] the preference value to mask
      # @return [String, nil] masked string, or nil if value is blank
      def self.mask(value)
        return nil if value.blank?

        value = value.to_s
        visible = value.length > VISIBLE_CHARACTERS ? value.last(VISIBLE_CHARACTERS) : ''
        # Never fewer than VISIBLE_CHARACTERS dots: `masked?` recognizes a
        # round-tripped value by that leading run, and a short secret must
        # not produce a mask the guard fails to spot.
        hidden = (value.length - visible.length).clamp(VISIBLE_CHARACTERS, MAX_MASK_LENGTH)

        "#{TOKEN_CHARACTER * hidden}#{visible}"
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

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

      # Money is written to at least the decimals of the currency the record
      # names (a calculator's `currency` preference), keeping up to four like
      # a unit price, so a per-item amount below a cent survives a round trip.
      # A money preference with no currency of its own, such as an order-total
      # rule that applies to any currency, keeps its exact decimal.
      def self.wire_value(preferable, type, value)
        case type
        when :password then mask(value)
        when :money
          # Stored as the JSON text of a decimal.
          amount = value.is_a?(String) ? BigDecimal(value, exception: false) : value
          return value unless amount.is_a?(Numeric)

          currency = preferable.try(:has_preference?, :currency) ? preferable.try(:preferred_currency) : nil
          currency.present? ? Spree::Money::Rounding.format(amount, currency, unit_price: true) : Spree::Money::Rounding.format_decimal(amount)
        else value
        end
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

        definitions = preferable.class.preference_definitions
        preferable.preference_schema.each_with_object({}) do |field, hash|
          # The stored value only, never the default — an unset secret must not
          # reveal what it would fall back to — read through the record,
          # because a secret lives in its own column.
          value = preferable.stored_preference(field[:key]) { nil }
          definition = definitions.fetch(field[:key])
          hash[field[:key_string] || field[:key].to_s] =
            definition[:of] == :id ? prefixed_ids(value, definition) : wire_value(preferable, field[:type], value)
        end
      end

      # Ids are stored as raw primary keys and leave as prefixed ids, the form
      # every write accepts.
      def self.prefixed_ids(value, definition)
        return value unless value.is_a?(Array)

        model = Spree::Preferences::Preferable.preference_model(definition)
        value.map { |id| Spree::PrefixedId.prefixed_id?(id.to_s) ? id : model.prefixed_id_for(id) }
      end
    end
  end
end

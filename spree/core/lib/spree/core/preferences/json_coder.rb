module Spree
  module Preferences
    # Raised when a preferences column still holds a YAML document — a row the
    # 6.0 conversion did not reach.
    class LegacyYamlError < StandardError
      def initialize(message = 'A preferences column still holds YAML. Run `bin/rake spree:upgrade:preferences_json` to convert it.')
        super
      end
    end

    # Stores preferences as a JSON object. Values are written in their JSON
    # form (`BigDecimal` as its exact string, dates as ISO 8601, symbols as
    # strings) and read back with indifferent access; the `preferred_*`
    # readers restore decimals from their declared type.
    #
    # For a JSON column, the column type has already decoded the value before
    # {.load} sees it, so a string reaching it can only be a leftover YAML
    # document.
    class JsonCoder
      # @param hash [Hash, nil]
      # @return [Hash, nil]
      def self.dump(hash)
        hash.nil? ? nil : hash.to_h.deep_stringify_keys.as_json
      end

      # @param value [Hash, String, nil]
      # @return [ActiveSupport::HashWithIndifferentAccess]
      def self.load(value)
        raise LegacyYamlError if value.is_a?(String)

        (value || {}).to_h.with_indifferent_access
      end
    end

    # The same contract for a `text` column, which stores the JSON as a
    # string — used by `secret_preferences`, whose ciphertext cannot live in
    # a JSON column. An empty column stays nil rather than reading as `{}`:
    # encrypted attributes compare the stored value with the loaded one, so
    # `{}` would mark every record without secrets as changed.
    class JsonTextCoder < JsonCoder
      def self.dump(hash)
        hash.nil? ? nil : ActiveSupport::JSON.encode(super)
      end

      def self.load(value)
        return if value.nil?

        super(value.is_a?(String) ? ActiveSupport::JSON.decode(value) : value)
      end
    end
  end
end

module Spree
  module Metafields
    class Json < Spree::Metafield
      validate :value_must_be_valid_json

      # Accept either a JSON-serialized String (from CSV / Admin UI text
      # input) or a raw Hash / Array (from API callers that ship parsed
      # objects). Non-String inputs get JSON-serialized so the underlying
      # text column always holds canonical JSON.
      #
      # @param raw [String, Hash, Array, nil]
      def value=(raw)
        super(raw.is_a?(Hash) || raw.is_a?(Array) ? raw.to_json : raw)
      end

      def serialize_value
        JSON.parse(value)
      rescue JSON::ParserError
        value
      end

      def csv_value
        value.to_s
      end

      private

      def value_must_be_valid_json
        return if value.blank?

        JSON.parse(value)
      rescue JSON::ParserError => e
        errors.add(:value, "must be valid JSON: #{e.message}")
      end
    end
  end
end

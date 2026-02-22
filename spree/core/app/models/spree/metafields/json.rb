module Spree
  module Metafields
    class Json < Spree::Metafield
      validate :value_must_be_valid_json

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

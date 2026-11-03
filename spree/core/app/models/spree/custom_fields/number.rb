module Spree
  module CustomFields
    class Number < Spree::CustomField
      validates :value, numericality: true

      def self.searchable?
        true
      end

      def self.sortable?
        true
      end

      def self.supported_validation_rules
        %w[min max]
      end

      def self.normalize_validation_bound(value, store: nil, rule: nil)
        decimal = Spree::Money::Rounding.parse_decimal(value) unless [true, false].include?(value)
        return if decimal.nil? || !decimal.finite?

        decimal.frac.zero? ? decimal.to_i : decimal.to_f
      rescue Spree::Money::InvalidFormat
        nil
      end

      def serialize_value
        value.to_d
      end

      def csv_value
        value.to_d.to_s
      end

      private

      def value_must_follow_definition_rules
        number = BigDecimal(value.to_s, exception: false)
        return if number.nil?

        add_bound_errors(number, below: :less_than_min, above: :greater_than_max, bound: ->(bound) { BigDecimal(bound.to_s) })
      end
    end
  end
end

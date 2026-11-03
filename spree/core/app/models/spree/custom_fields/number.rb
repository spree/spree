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

      def self.normalize_validation_bound(value, store: nil)
        return if [true, false].include?(value)

        decimal = BigDecimal(value.to_s)
        return unless decimal.finite?

        decimal.frac.zero? ? decimal.to_i : decimal.to_f
      rescue ArgumentError, TypeError
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

        min, max = definition_rules.values_at('min', 'max')
        if min && number < BigDecimal(min.to_s)
          errors.add(:value, :less_than_min, min: min, message: I18n.t('spree.errors.messages.custom_field_less_than_min', min: min))
        end
        if max && number > BigDecimal(max.to_s)
          errors.add(:value, :greater_than_max, max: max, message: I18n.t('spree.errors.messages.custom_field_greater_than_max', max: max))
        end
      end
    end
  end
end

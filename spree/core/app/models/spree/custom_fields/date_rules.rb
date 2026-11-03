module Spree
  module CustomFields
    # Shared by the date types: the value is kept in one canonical ISO 8601
    # shape, so stored values, `min` / `max` rules and `cf_` filter values
    # compare correctly as text.
    module DateRules
      extend ActiveSupport::Concern

      included do
        before_validation :normalize_date_value
        validate :value_must_be_canonical
      end

      class_methods do
        def searchable?
          true
        end

        def sortable?
          true
        end

        def supported_validation_rules
          %w[min max]
        end

        def normalize_validation_bound(value, store: nil)
          canonical_value(value, store: store)
        end

        # A `cf_` filter as `[operator, canonical bound]` pairs, all of which
        # must hold.
        #
        # @param predicate [String] eq, gt, gteq, lt or lteq
        # @return [Array<Array(String, String)>, nil] nil when the value cannot be read
        def filter_conditions(predicate, input, store: nil)
          bound = canonical_value(input, store: store)
          bound && [[predicate, bound]]
        end

        private

        # Accepts a space between date and time, as filter inputs send it.
        def iso8601_input(input)
          input.strip.sub(/\A(\d{4}-\d{2}-\d{2}) (?=\d)/, '\\1T')
        end
      end

      private

      def date_store
        custom_field_definition&.store
      end

      def normalize_date_value
        canonical = self.class.canonical_value(value, store: date_store)
        self.value = canonical if canonical
      end

      def value_must_be_canonical
        return if value.blank? || self.class.canonical_value(value, store: date_store) == value

        errors.add(:value, invalid_value_error, message: I18n.t("spree.errors.messages.custom_field_#{invalid_value_error}"))
      end

      def value_must_follow_definition_rules
        return unless self.class.canonical_value(value, store: date_store) == value

        min, max = definition_rules.values_at('min', 'max')

        if min && value < min
          errors.add(:value, :before_min, min: min, message: I18n.t('spree.errors.messages.custom_field_before_min', min: min))
        end
        if max && value > max
          errors.add(:value, :after_max, max: max, message: I18n.t('spree.errors.messages.custom_field_after_max', max: max))
        end
      end
    end
  end
end

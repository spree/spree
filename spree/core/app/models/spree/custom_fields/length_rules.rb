module Spree
  module CustomFields
    # `min` / `max` as a character count, for the text types.
    module LengthRules
      extend ActiveSupport::Concern

      class_methods do
        def supported_validation_rules
          %w[min max]
        end

        def normalize_validation_bound(value, store: nil)
          bound = Integer(value.to_s, exception: false) unless [true, false].include?(value)
          bound if bound && bound >= 0
        end
      end

      private

      def value_must_follow_definition_rules
        min, max = definition_rules.values_at('min', 'max')

        if min && value.length < min
          errors.add(:value, :too_short, count: min, message: I18n.t('spree.errors.messages.custom_field_too_short', count: min))
        end
        if max && value.length > max
          errors.add(:value, :too_long, count: max, message: I18n.t('spree.errors.messages.custom_field_too_long', count: max))
        end
      end
    end
  end
end

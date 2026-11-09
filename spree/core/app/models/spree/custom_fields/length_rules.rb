module Spree
  module CustomFields
    # `min` / `max` as a character count, for the text types.
    module LengthRules
      extend ActiveSupport::Concern

      class_methods do
        def supported_validation_rules
          %w[min max]
        end

        def normalize_validation_bound(value, **)
          bound = Integer(value.to_s, 10, exception: false) unless [true, false].include?(value)
          bound if bound && bound >= 0
        end
      end

      private

      def value_must_follow_definition_rules
        add_bound_errors(value.length, below: :too_short, above: :too_long)
      end
    end
  end
end

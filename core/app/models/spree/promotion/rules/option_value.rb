module Spree
  class Promotion
    module Rules
      class OptionValue < PromotionRule
        MATCH_POLICIES = %w(any)
        preference :match_policy, :string, default: MATCH_POLICIES.first
        preference :eligible_values, :array, default: [], parse_on_set: lambda { |values|
          values.flat_map { |v| v.to_s.split(',').compact_blank.map(&:strip) }
        }

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(promotable, _options = {})
          case preferred_match_policy
          when 'any'
            promotable.line_items.any? { |item| actionable?(item) }
          end
        end

        def actionable?(line_item)
          option_value_variant_ids = line_item.variant.option_value_variant_ids.map(&:to_s)
          (preferred_eligible_values & option_value_variant_ids).any?
        end
      end
    end
  end
end

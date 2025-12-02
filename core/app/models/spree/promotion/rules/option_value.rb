module Spree
  class Promotion
    module Rules
      class OptionValue < PromotionRule
        MATCH_POLICIES = %w(any)
        preference :match_policy, :string, default: MATCH_POLICIES.first
        preference :eligible_values, :array, default: [], parse_on_set: lambda { |values|
          values.flat_map { |v| v.to_s.split(',').compact_blank.map(&:strip) }
        }

        # We need this for automatic promotions when removing item that activated the promo
        # Otherwise it will be an issue when using it with the Create Line Items promo action
        def applicable?(promotable)
          promotable.is_a?(Spree::Order) || (promotable.is_a?(Spree::LineItem) && promotion.present? && promotion.automatic?)
        end

        def eligible?(promotable, _options = {})
          return false unless promotable.is_a?(Spree::Order)

          case preferred_match_policy
          when 'any'
            promotable.line_items.reload.any? { |item| actionable?(item) }
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

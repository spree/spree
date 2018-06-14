module Spree
  class Promotion
    module Rules
      class OptionValue < PromotionRule
        MATCH_POLICIES = %w(any)
        preference :match_policy, :string, default: MATCH_POLICIES.first
        preference :eligible_values, :hash

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
          product_id = line_item.product.id
          option_values_ids = line_item.variant.option_value_ids
          eligible_product_ids = preferred_eligible_values.keys
          eligible_value_ids = preferred_eligible_values[product_id]

          eligible_product_ids.include?(product_id) && (eligible_value_ids & option_values_ids).present?
        end
      end
    end
  end
end

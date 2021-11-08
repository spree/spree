module Spree
  module Api
    module V2
      module Platform
        class PromotionsController < ResourceController
          private

          def model_class
            Spree::Promotion
          end

          def scope_includes
            [:promotion_category, :promotion_rules, :promotion_actions]
          end

          def spree_permitted_attributes
            rule_params = [:preferred_match_policy, :preferred_country_id, :preferred_amount_min, :preferred_operator_min, :preferred_amount_max,
                           :preferred_operator_max, :preferred_eligible_values, { taxon_ids: [], user_ids: [] }]

            calculator_params = [:preferred_flat_percent, :preferred_amount, :preferred_currency, :preferred_first_item, :preferred_additional_item,
                                 :preferred_max_items, :preferred_percent, :preferred_minimal_amount, :preferred_normal_amount,
                                 :preferred_discount_amount, :preferred_currency, :preferred_base_amount, :preferred_tiers, :preferred_base_percent]

            conditional_params = action_name == 'update' ? [:id] : []

            super + [{ promotion_actions_attributes: Spree::PromotionAction.json_api_permitted_attributes.concat(conditional_params) + [{
              promotion_action_line_items_attributes: Spree::PromotionActionLineItem.json_api_permitted_attributes.concat(conditional_params),
              calculator_attributes: Spree::Calculator.json_api_permitted_attributes.concat(conditional_params, calculator_params)
            }], promotion_rules_attributes: Spree::PromotionRule.json_api_permitted_attributes.concat(conditional_params, rule_params) }]
          end
        end
      end
    end
  end
end

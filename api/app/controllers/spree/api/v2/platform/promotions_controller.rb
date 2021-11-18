module Spree
  module Api
    module V2
      module Platform
        class PromotionsController < ResourceController
          include ::Spree::Api::V2::Platform::PromotionRuleParams
          include ::Spree::Api::V2::Platform::PromotionCalculatorParams

          private

          def model_class
            Spree::Promotion
          end

          def scope_includes
            [:promotion_category, :promotion_rules, :promotion_actions]
          end

          def spree_permitted_attributes
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

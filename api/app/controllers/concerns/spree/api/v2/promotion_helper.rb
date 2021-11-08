module Spree
  module Api
    module V2
      module PromotionHelper
        private

        def spree_permitted_attributes
          promotion_rules_permitted_attributes = [:preferred_match_policy, :preferred_country_id, :preferred_amount_min,
                                                  :preferred_operator_min, :preferred_amount_max, :preferred_operator_max,
                                                  :preferred_eligible_values]

          calculator_permitted_attributes = [:preferred_flat_percent, :preferred_amount, :preferred_currency, :preferred_first_item,
                                             :preferred_additional_item, :preferred_max_items, :preferred_percent, :preferred_minimal_amount,
                                             :preferred_normal_amount, :preferred_discount_amount, :preferred_currency, :preferred_base_amount,
                                             :preferred_tiers, :preferred_base_percent]

          additional_permitted_attributes = action_name == 'update' ? [:id] : []

          super + [
            {
              promotion_actions_attributes: Spree::PromotionAction.
                  json_api_permitted_attributes.
                  concat(additional_permitted_attributes) + [
                    {
                      promotion_action_line_items_attributes: Spree::PromotionActionLineItem.
                                                            json_api_permitted_attributes.
                                                            concat(additional_permitted_attributes),
                      calculator_attributes: Spree::Calculator.
                                                            json_api_permitted_attributes.
                                                            concat(additional_permitted_attributes,
                                                                   calculator_permitted_attributes)
                    }
                  ],

              promotion_rules_attributes: Spree::PromotionRule.
                  json_api_permitted_attributes.
                  concat(additional_permitted_attributes, promotion_rules_permitted_attributes)
            }
          ]
        end
      end
    end
  end
end

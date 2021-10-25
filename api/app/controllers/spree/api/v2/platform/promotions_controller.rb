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
            [:promotion_category, :promotion_rules, :promotion_actions, :promotion_action_line_items]
          end

          def spree_permitted_attributes
            promotion_rules = [:preferred_match_policy]
            additional_permitted_attributes = if action_name == 'update'
                                                [:id, :_destroy]
                                              else
                                                []
                                              end

            Spree::Promotion.json_api_permitted_attributes + [
              :store_ids,
              {
                promotion_actions_attributes: Spree::PromotionAction.
                                                             json_api_permitted_attributes.
                                                             concat(additional_permitted_attributes) + [
                                                               {
                                                                 promotion_action_line_items_attributes: Spree::PromotionActionLineItem.
                                                                                                       json_api_permitted_attributes.
                                                                                                       concat(additional_permitted_attributes)
                                                               }
                                                             ],

                promotion_rules_attributes: Spree::PromotionRule.
                                                             json_api_permitted_attributes.
                                                             concat(additional_permitted_attributes, promotion_rules)
              }
            ]
          end
        end
      end
    end
  end
end

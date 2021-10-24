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
            promotion_actions = []
            promotion_rules = []

            resource.promotion_actions.each do |promotion_action|
              promotion_action.defined_preferences.each do |preference|
                promotion_actions << "preferred_#{preference}".to_sym
              end
            end

            resource.promotion_rules.each do |promotion_rule|
              promotion_rule.defined_preferences.each do |preference|
                promotion_rules << "preferred_#{preference}".to_sym
              end
            end

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
                                                             concat(additional_permitted_attributes,
                                                                    promotion_actions) + [
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

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
            additional_permitted_attributes = if action_name == 'update'
                                                [:id]
                                              else
                                                []
                                              end

            Spree::Promotion.json_api_permitted_attributes.push(:store_ids) + [
              promotion_actions_attributes: Spree::PromotionAction.json_api_permitted_attributes.concat(additional_permitted_attributes),
              promotion_rules_attributes: Spree::PromotionRule.json_api_permitted_attributes.concat(additional_permitted_attributes)
            ]
          end
        end
      end
    end
  end
end
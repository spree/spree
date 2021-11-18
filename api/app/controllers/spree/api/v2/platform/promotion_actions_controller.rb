module Spree
  module Api
    module V2
      module Platform
        class PromotionActionsController < ResourceController
          include ::Spree::Api::V2::Platform::PromotionCalculatorParams

          private

          def model_class
            Spree::PromotionAction
          end

          def scope_includes
            [:promotion]
          end

          def spree_permitted_attributes
            conditional_params = action_name == 'update' ? [:id] : []

            super + [{
              promotion_action_line_items_attributes: Spree::PromotionActionLineItem.json_api_permitted_attributes.concat(conditional_params),
              calculator_attributes: Spree::Calculator.json_api_permitted_attributes.concat(conditional_params, calculator_params)
            }]
          end
        end
      end
    end
  end
end

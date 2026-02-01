module Spree
  module Api
    module V2
      module Platform
        class PromotionRulesController < ResourceController
          include ::Spree::Api::V2::Platform::PromotionRuleParams

          private

          def model_class
            Spree::PromotionRule
          end

          def scope_includes
            [:promotion]
          end

          def spree_permitted_attributes
            super + rule_params
          end

          def resource_serializer
            Spree.api.platform_promotion_rule_serializer
          end
        end
      end
    end
  end
end

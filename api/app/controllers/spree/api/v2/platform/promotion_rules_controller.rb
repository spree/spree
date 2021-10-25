module Spree
  module Api
    module V2
      module Platform
        class PromotionRulesController < ResourceController
          private

          def model_class
            Spree::PromotionRule
          end

          def scope_includes
            [:promotion]
          end
        end
      end
    end
  end
end

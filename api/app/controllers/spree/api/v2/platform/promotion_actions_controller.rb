module Spree
  module Api
    module V2
      module Platform
        class PromotionActionsController < ResourceController
          private

          def model_class
            Spree::PromotionAction
          end

          def scope_includes
            [:promotion]
          end
        end
      end
    end
  end
end

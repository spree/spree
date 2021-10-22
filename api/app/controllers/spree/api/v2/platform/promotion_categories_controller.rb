module Spree
  module Api
    module V2
      module Platform
        class PromotionCategoriesController < ResourceController
          private

          def model_class
            Spree::PromotionCategory
          end

          def scope_includes
            [:promotions]
          end
        end
      end
    end
  end
end

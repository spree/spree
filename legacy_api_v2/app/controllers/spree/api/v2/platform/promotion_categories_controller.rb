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

          def resource_serializer
            Spree.api.platform_promotion_category_serializer
          end
        end
      end
    end
  end
end

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
            Spree::Api::Dependencies.platform_promotion_category_serializer.constantize
          end
        end
      end
    end
  end
end

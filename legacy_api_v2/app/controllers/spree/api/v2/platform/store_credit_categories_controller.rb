module Spree
  module Api
    module V2
      module Platform
        class StoreCreditCategoriesController < ResourceController
          private

          def model_class
            Spree::StoreCreditCategory
          end

          def resource_serializer
            Spree.api.platform_store_credit_category_serializer
          end
        end
      end
    end
  end
end

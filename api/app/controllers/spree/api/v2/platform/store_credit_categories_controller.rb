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
            Spree::Api::Dependencies.platform_store_credit_category_serializer.constantize
          end
        end
      end
    end
  end
end

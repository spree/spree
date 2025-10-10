module Spree
  module Api
    module V2
      module Platform
        class StoreCreditTypesController < ResourceController
          private

          def model_class
            Spree::StoreCreditType
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_store_credit_type_serializer.constantize
          end
        end
      end
    end
  end
end

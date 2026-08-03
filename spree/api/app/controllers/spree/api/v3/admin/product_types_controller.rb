module Spree
  module Api
    module V3
      module Admin
        class ProductTypesController < ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::ProductType
          end

          def serializer_class
            Spree.api.admin_product_type_serializer
          end

          def permitted_params
            params.permit(:name, fulfillment_types: [])
          end
        end
      end
    end
  end
end

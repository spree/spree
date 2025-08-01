module Spree
  module Api
    module V2
      module Platform
        class ShippingCategoriesController < ResourceController
          private

          def model_class
            Spree::ShippingCategory
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_shipping_category_serializer.constantize
          end
        end
      end
    end
  end
end

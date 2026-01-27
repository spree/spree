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
            Spree.api.platform_shipping_category_serializer
          end
        end
      end
    end
  end
end

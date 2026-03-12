module Spree
  module Api
    module V3
      module Admin
        class ShippingCategoriesController < ResourceController
          protected

          def model_class
            Spree::ShippingCategory
          end

          def serializer_class
            Spree.api.admin_shipping_category_serializer
          end
        end
      end
    end
  end
end

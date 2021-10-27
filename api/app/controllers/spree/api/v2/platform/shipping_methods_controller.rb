module Spree
  module Api
    module V2
      module Platform
        class ShippingMethodsController < ResourceController
          private

          def model_class
            Spree::ShippingMethod
          end

          def spree_permitted_attributes
            Spree::ShippingMethod.json_api_permitted_attributes + [
              {
                shipping_category_ids: [],
                calculator_attributes: {}
              }
            ]
          end
        end
      end
    end
  end
end

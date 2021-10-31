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
            super + [
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

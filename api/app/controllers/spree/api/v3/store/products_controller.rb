module Spree
  module Api
    module V3
      module Store
        class ProductsController < Store::ResourceController
          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.product_serializer
          end

          def scope
            super.available
          end

          def scope_includes
            [
              master: [:prices, { stock_items: :stock_location }],
              variants: [:prices, {option_values: :option_type }, { stock_items: :stock_location }]
            ]
          end
        end
      end
    end
  end
end

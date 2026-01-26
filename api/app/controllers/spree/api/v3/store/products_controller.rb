module Spree
  module Api
    module V3
      module Store
        class ProductsController < ResourceController
          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.product_serializer
          end

          # Find product by slug or prefix_id with i18n scope for SEO-friendly URLs
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('prod_')
              scope.find_by!(prefix_id: id)
            else
              scope.i18n.find_by!(slug: id)
            end
          end

          def scope
            super.available
          end

          def scope_includes
            [
              master: [:prices, { stock_items: :stock_location }],
              variants: [:prices, { option_values: :option_type }, { stock_items: :stock_location }]
            ]
          end
        end
      end
    end
  end
end

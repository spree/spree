module Spree
  module Api
    module V3
      module Storefront
        class ProductsController < ResourceController
          include Spree::Api::V2::ProductListIncludes

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_product_serializer.constantize
          end

          def scope
            super.available
          end

          def scope_includes
            [
              :prices_including_master,
              :variant_images,
              :option_types,
              :option_values,
              :taxons,
              { taggings: [:tag] },
              { master: [:images, :prices, :stock_items, :stock_locations, { stock_items: :stock_location }],
                variants: [
                  :images, :prices, :option_values, :stock_items, :stock_locations,
                  { option_values: :option_type, stock_items: :stock_location }
                ],
              }
            ]
          end

          # Not needed for index/show, but required by ResourceController
          def permitted_params
            {}
          end
        end
      end
    end
  end
end

module Spree
  module Api
    module V2
      module Platform
        class ProductsController < ResourceController
          private

          def model_class
            Spree::Product
          end

          def scope_includes
            {
              master: :default_price,
              variants: [],
              variant_images: [],
              taxons: [],
              product_properties: :property,
              option_types: :option_values,
              variants_including_master: %i[default_price option_values]
            }
          end
        end
      end
    end
  end
end

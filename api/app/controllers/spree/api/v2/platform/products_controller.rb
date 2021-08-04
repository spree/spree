module Spree
  module Api
    module V2
      module Platform
        class ProductsController < ResourceController
          include ::Spree::Api::V2::ProductListIncludes

          private

          def model_class
            Spree::Product
          end

          def scope_includes
            product_list_includes
          end
        end
      end
    end
  end
end

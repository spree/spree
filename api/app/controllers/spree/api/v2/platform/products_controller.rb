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

          def spree_permitted_attributes
            super.push(:price)
          end

          def allowed_sort_attributes
            super.push(:available_on, :make_active_at)
          end

          def sorted_collection
            collection_sorter.new(collection, current_currency, params, allowed_sort_attributes).call
          end

          def collection_sorter
            Spree::Api::Dependencies.platform_products_sorter.constantize
          end
        end
      end
    end
  end
end

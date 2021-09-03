module Spree
  module Api
    module V2
      module Storefront
        class ProductsController < ::Spree::Api::V2::ResourceController
          include ::Spree::Api::V2::ProductListIncludes

          protected

          def sorted_collection
            collection_sorter.new(collection, current_currency, params, allowed_sort_attributes).call
          end

          def collection
            @collection ||= collection_finder.new(scope: scope, params: finder_params).execute
          end

          def resource
            @resource ||= scope.find_by(slug: params[:id]) || scope.find(params[:id])
          end

          def collection_sorter
            Spree::Api::Dependencies.storefront_products_sorter.constantize
          end

          def collection_finder
            Spree::Api::Dependencies.storefront_products_finder.constantize
          end

          def collection_serializer
            Spree::Api::Dependencies.storefront_product_serializer.constantize
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_product_serializer.constantize
          end

          def model_class
            Spree::Product
          end

          def scope_includes
            product_list_includes
          end

          def allowed_sort_attributes
            super << :available_on
          end

          def collection_meta(collection)
            super(collection).merge(filters: serialized_filters)
          end

          def serialized_filters
            option_values = Spree::OptionValues::FindAvailable.new(products_scope: products_for_filters).execute
            product_properties = Spree::ProductProperties::FindAvailable.new(products_scope: products_for_filters).execute

            {
              option_types: Spree::Products::OptionTypeFiltersPresenter.new(option_values).to_a,
              product_properties: Spree::Products::PropertyFiltersPresenter.new(product_properties).to_a
            }
          end

          def products_for_filters
            @products_for_filters ||= current_store.products.for_filters(current_currency, taxon: nil)
          end
        end
      end
    end
  end
end

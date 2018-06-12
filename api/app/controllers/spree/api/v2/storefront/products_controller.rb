module Spree
  module Api
    module V2
      module Storefront
        class ProductsController < ::Spree::Api::V2::BaseController
          def index
            render json: serialize_collection(collection), status: 200
          end

          def show
            render json: serialize_resource(resource), status: 200
          end

          private

          def serialize_collection(collection)
            dependencies[:collection_serializer].new(
              collection,
              include: %i[]
            ).serializable_hash
          end

          def serialize_resource(resource)
            dependencies[:resource_serializer].new(
              resource,
              include: %i[
                variants
                variants.images
                option_types
                option_types.option_values
              ]
            ).serializable_hash
          end

          def collection
            dependencies[:finder].new(scope, params).call
          end

          def resource
            scope.find_by(slug: params[:id]) || scope.find(params[:id])
          end

          def dependencies
            {
              resource_serializer:   Spree::V2::Storefront::ProductSerializer,
              collection_serializer: Spree::V2::Storefront::ProductSerializer,
              finder:                Spree::Products::Find
            }
          end

          def scope
            Spree::Product.includes(
              variants:     :default_price,
              option_types: :option_values
            )
          end
        end
      end
    end
  end
end

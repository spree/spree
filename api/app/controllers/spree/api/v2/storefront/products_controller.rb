module Spree
  module Api
    module V2
      module Storefront
        class ProductsController < ::Spree::Api::V2::BaseController
          def show
            run_with_bad_request_handling do
              render json: serialize_resource(resource), status: 200
            end
          end

          private

          def serialize_resource(resource)
            dependencies[:resource_serializer].new(
              resource,
              include: resource_includes
            ).serializable_hash
          end

          def resource
            scope.find_by(slug: params[:id]) || scope.find(params[:id])
          end

          def dependencies
            {
              resource_serializer: Spree::V2::Storefront::ProductSerializer
            }
          end

          def scope
            Spree::Product.includes(scope_includes)
          end

          def resource_includes
            request_includes || default_resource_includes
          end

          def default_resource_includes
            %i[
              variants
              variants.images
              default_variant
              default_variant.images
              option_types
              option_types.option_values
              product_properties
            ]
          end

          def scope_includes
            {
              product_properties: :property,
              variants:           :default_price,
              option_types:       :option_values
            }
          end
        end
      end
    end
  end
end

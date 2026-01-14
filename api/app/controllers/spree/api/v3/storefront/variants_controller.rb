module Spree
  module Api
    module V3
      module Storefront
        class VariantsController < ResourceController
          before_action :set_product

          # GET /api/v3/storefront/products/:product_id/variants/:id
          def show
            @resource = @product.variants.find(params[:id])
            render json: serialize_resource(@resource)
          end

          protected

          def set_product
            @product = Spree::Product.available.for_store(current_store).find(params[:product_id])
          end

          def scope
            @product.variants.accessible_by(current_ability, :show).includes(scope_includes)
          end

          def scope_includes
            [:prices, { stock_items: :stock_location }]
          end

          def model_class
            Spree::Variant
          end

          def serializer_class
            Spree.api.v3_storefront_variant_serializer
          end

          # Not needed for index/show
          def permitted_params
            {}
          end
        end
      end
    end
  end
end

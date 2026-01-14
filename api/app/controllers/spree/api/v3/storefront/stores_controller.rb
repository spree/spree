module Spree
  module Api
    module V3
      module Storefront
        class StoresController < ResourceController
          # Public endpoint - no authentication required

          # GET /api/v3/storefront/store
          def current
            @store = current_store
            render json: serialize_resource(@store)
          end

          # GET /api/v3/storefront/stores/:code
          def show
            @resource = Spree::Store.find_by!(code: params[:id])
            render json: serialize_resource(@resource)
          end

          protected

          def model_class
            Spree::Store
          end

          def serializer_class
            Spree.api.v3_storefront_store_serializer
          end

          # Not needed for show
          def permitted_params
            {}
          end
        end
      end
    end
  end
end

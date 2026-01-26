module Spree
  module Api
    module V3
      module Store
        class StoresController < ResourceController
          # Public endpoint - no authentication required

          # GET  /api/v3/store/store
          def current
            @store = current_store
            render json: serialize_resource(@store)
          end

          # GET  /api/v3/store/stores/:code
          def show
            @resource = Spree::Store.find_by!(code: params[:id])
            render json: serialize_resource(@resource)
          end

          protected

          def model_class
            Spree::Store
          end

          def serializer_class
            Spree.api.store_serializer
          end
        end
      end
    end
  end
end

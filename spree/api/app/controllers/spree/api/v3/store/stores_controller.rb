module Spree
  module Api
    module V3
      module Store
        class StoresController < ResourceController
          skip_before_action :set_resource

          # GET /api/v3/store/store
          def show
            render json: serialize_resource(current_store)
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

module Spree
  module Api
    module V3
      module Store
        class StoreController < Store::BaseController
          allow_guest_storefront_access!
          include Spree::Api::V3::HttpCaching

          # GET /api/v3/store/store
          def show
            return unless cache_resource(current_store)

            render json: serializer_class.new(current_store, params: serializer_params).to_h
          end

          private

          def serializer_class
            Spree.api.store_serializer
          end
        end
      end
    end
  end
end

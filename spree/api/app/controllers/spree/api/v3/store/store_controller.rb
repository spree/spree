module Spree
  module Api
    module V3
      module Store
        # Exposes the store the request resolved to, so a storefront can render
        # its name and default SEO metadata in the requested locale.
        class StoreController < Store::BaseController
          # A gated storefront still needs a page title on its sign-in wall.
          allow_guest_storefront_access!

          # GET /api/v3/store/store
          def show
            render json: serialize_resource(current_store)
          end

          protected

          def serializer_class
            Spree.api.store_serializer
          end
        end
      end
    end
  end
end

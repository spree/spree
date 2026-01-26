module Spree
  module Api
    module V3
      module Store
        class WishlistsController < ResourceController
          prepend_before_action :require_authentication!

          # POST /api/v3/store/wishlists
          def create
            @resource = current_user.wishlists.build(permitted_params)
            @resource.store = current_store

            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_errors(@resource.errors)
            end
          end

          protected

          def scope
            current_user.wishlists.for_store(current_store)
          end

          def model_class
            Spree::Wishlist
          end

          def serializer_class
            Spree.api.wishlist_serializer
          end

          def permitted_params
            params.require(:wishlist).permit(Spree::PermittedAttributes.wishlist_attributes)
          end
        end
      end
    end
  end
end

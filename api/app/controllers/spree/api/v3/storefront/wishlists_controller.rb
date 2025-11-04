module Spree
  module Api
    module V3
      module Storefront
        class WishlistsController < ResourceController
          before_action :require_authentication!

          # GET /api/v3/storefront/wishlists/default
          def default
            @wishlist = current_user.wishlists.default.first_or_create!(
              name: 'Default',
              is_default: true,
              store: current_store
            )

            render json: serialize_resource(@wishlist)
          end

          protected

          def scope
            current_user.wishlists.for_store(current_store)
          end

          def model_class
            Spree::Wishlist
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_wishlist_serializer.constantize
          end

          def permitted_params
            params.require(:wishlist).permit(Spree::PermittedAttributes.wishlist_attributes)
          end
        end
      end
    end
  end
end

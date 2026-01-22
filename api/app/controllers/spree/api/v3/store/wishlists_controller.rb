module Spree
  module Api
    module V3
      module Store
        class WishlistsController < ResourceController
          before_action :require_authentication!

          protected

          def scope
            current_user.wishlists.for_store(current_store)
          end

          def model_class
            Spree::Wishlist
          end

          def serializer_class
            Spree.api.v3_store_wishlist_serializer
          end

          def permitted_params
            params.require(:wishlist).permit(Spree::PermittedAttributes.wishlist_attributes)
          end
        end
      end
    end
  end
end

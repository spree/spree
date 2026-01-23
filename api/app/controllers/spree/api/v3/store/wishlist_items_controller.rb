module Spree
  module Api
    module V3
      module Store
        class WishlistItemsController < ResourceController
          before_action :require_authentication!
          before_action :set_wishlist

          protected

          def set_wishlist
            @wishlist = current_user.wishlists.find(params[:wishlist_id])
          end

          def scope
            @wishlist.wished_items
          end

          def model_class
            Spree::WishedItem
          end

          def serializer_class
            Spree.api.v3_store_wished_item_serializer
          end

          def permitted_params
            params.require(:item).permit(Spree::PermittedAttributes.wished_item_attributes)
          end
        end
      end
    end
  end
end

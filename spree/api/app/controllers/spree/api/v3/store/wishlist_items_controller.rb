module Spree
  module Api
    module V3
      module Store
        class WishlistItemsController < ResourceController
          prepend_before_action :require_authentication!

          protected

          def set_parent
            @parent = storefront_access_policy.
                      scope(Spree::Wishlist.for_store(current_store)).
                      find_by_prefix_id!(params[:wishlist_id])
            authorize_storefront_write!(@parent)
          end

          def parent_association
            :wishlist_items
          end

          def model_class
            Spree::WishlistItem
          end

          def serializer_class
            Spree.api.wishlist_item_serializer
          end

          def resource_permitted_attributes
            [:variant_id, :quantity]
          end
        end
      end
    end
  end
end

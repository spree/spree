module Spree
  module Api
    module V3
      module Store
        class WishlistItemsController < ResourceController
          include Spree::Api::V3::Store::StorefrontProducts

          prepend_before_action :require_authentication!

          request_params 'CreateWishlistItemParams', action: :create do |body|
            body.attribute :variant_id, :id, required: true, example: 'variant_abc123'
            body.attribute :quantity, :integer, example: 1
          end

          request_params 'UpdateWishlistItemParams', action: :update do |body|
            body.attribute :variant_id, :id, description: 'Moves the item to another variant.'
            body.attribute :quantity, :integer, example: 2
          end

          protected

          def set_parent
            @parent = storefront_access_policy.
                      scope(Spree::Wishlist.for_store(current_store)).
                      find_by_prefix_id!(params[:wishlist_id])
            authorize_storefront_write!(@parent)
          end

          def model_class
            Spree::WishlistItem
          end

          def serializer_class
            Spree.api.wishlist_item_serializer
          end

          # The item renders its variant and product, so the variant must be
          # one the buyer could find in the listing — not a draft, another
          # catalog's product, or an id guessed from the sequence.
          def permitted_params
            @permitted_params ||= super.tap do |attributes|
              attributes[:variant_id] = storefront_variants.find_by_prefix_id!(params[:variant_id]).id if params.key?(:variant_id)
            end
          end
        end
      end
    end
  end
end

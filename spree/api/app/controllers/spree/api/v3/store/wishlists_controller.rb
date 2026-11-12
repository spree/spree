module Spree
  module Api
    module V3
      module Store
        class WishlistsController < ResourceController
          prepend_before_action :require_authentication!

          request_params 'CreateWishlistParams', action: :create do |body|
            body.attribute :name, :string, required: true, example: 'Birthday Ideas'
            body.attribute :is_private, :boolean
            body.attribute :is_default, :boolean
          end

          request_params 'UpdateWishlistParams', action: :update do |body|
            body.attribute :name, :string, example: 'Updated Name'
            body.attribute :is_private, :boolean
            body.attribute :is_default, :boolean
          end

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
            storefront_access_policy.scope(Spree::Wishlist.for_store(current_store))
          end

          def model_class
            Spree::Wishlist
          end

          def serializer_class
            Spree.api.wishlist_serializer
          end
        end
      end
    end
  end
end

module Spree
  module Api
    module V2
      module Storefront
        class WishlistsController < ::Spree::Api::V2::ResourceController
          include Spree::Api::V2::CollectionOptionsHelpers

          before_action :require_spree_current_user

          def index
            spree_authorize! :index, Spree::Wishlist

            wishlists = spree_current_user.wishlists.for_store(current_store).page(params[:page]).per(params[:per_page])

            render_serialized_payload { serialize_collection(wishlists) }
          end

          def create
            spree_authorize! :create, Spree::Wishlist
            wishlist = spree_current_user.wishlists.new(wishlist_attributes)

            ensure_current_store(wishlist)

            wishlist.save

            if wishlist.persisted?
              render_serialized_payload(201) { serialize_resource(wishlist) }
            else
              render_error_payload(wishlist.errors.full_messages.to_sentence)
            end
          end

          def show
            render_serialized_payload { serialize_resource(resource) }
          end

          def update
            authorize! :update, resource
            resource.update wishlist_attributes

            if resource.errors.empty?
              render_serialized_payload { serialize_resource(resource) }
            else
              render_error_payload(resource.errors.full_messages.to_sentence)
            end
          end

          def destroy
            authorize! :destroy, resource
            if resource.destroy
              render_serialized_payload { serialize_resource(resource) }
            else
              render_error_payload('Something went wrong')
            end
          end

          def default
            spree_authorize! :create, Spree::Wishlist
            default_wishlist = spree_current_user.default_wishlist_for_store(current_store)

            render_serialized_payload { serialize_resource(default_wishlist) }
          end

          private

          def wishlist_attributes
            params.require(:wishlist).permit(permitted_wishlist_attributes)
          end

          def resource
            @resource ||= scope.find_by!(token: params[:id])
          end

          def scope
            current_store.wishlists
          end

          def resource_serializer
            ::Spree::V2::Storefront::WishlistSerializer
          end

          def collection_serializer
            ::Spree::V2::Storefront::WishlistSerializer
          end
        end
      end
    end
  end
end

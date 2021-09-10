module Spree
  module Api
    module V2
      module Storefront
        class WishlistsController < ::Spree::Api::V2::ResourceController
          include Spree::Api::V2::CollectionOptionsHelpers

          before_action :require_spree_current_user, except: [:show]

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

          def add_item
            spree_authorize! :create, Spree::WishedVariant
            spree_authorize! :update, resource

            wished_variant = Spree::WishedVariant.new(params.permit(:quantity, :remark, :variant_id))

            if resource.include? params[:variant_id]
              wished_variant = resource.wished_variants.detect { |wv| wv.variant_id == params[:variant_id] }
            else
              wished_variant.wishlist = resource
              wished_variant.save
            end

            resource.reload

            if wished_variant.persisted?
              render_serialized_payload { serialize_wished_variant(wished_variant) }
            else
              render_error_payload(resource.errors.full_messages.to_sentence)
            end
          end

          def update_item_quantity
            return render_error_item_quantity unless params[:quantity].to_i > 0

            spree_authorize! :update, wished_variant

            wished_variant.update(params.permit(:quantity))

            if wished_variant.errors.empty?
              render_serialized_payload { serialize_wished_variant(wished_variant) }
            else
              render_error_payload(resource.errors.full_messages.to_sentence)
            end
          end

          def remove_item
            spree_authorize! :update, wished_variant

            if wished_variant.destroy
              render_serialized_payload { serialize_wished_variant(wished_variant) }
            else
              render_error_payload('Something went wrong')
            end
          end

          private

          def resource
            @resource ||= current_store.wishlists.find_by!(token: params[:id])
          end

          def resource_serializer
            ::Spree::V2::Storefront::WishlistSerializer
          end

          def collection_serializer
            ::Spree::V2::Storefront::WishlistSerializer
          end

          def wishlist_attributes
            params.require(:wishlist).permit(permitted_wishlist_attributes)
          end

          def wished_variant_attributes
            params.permit(permitted_wished_variant_attributes)
          end

          def wished_variant
            @wished_variant ||= resource.wished_variants.find(params[:wished_variant_id])
          end

          def serialize_wished_variant(wished_variant)
            wished_variant_serializer.new(
              wished_variant,
              params: serializer_params,
              include: resource_includes,
              fields: sparse_fields
            ).serializable_hash
          end

          def wished_variant_serializer
            ::Spree::V2::Storefront::WishedVariantSerializer
          end

          def render_error_item_quantity
            render json: { error: I18n.t('spree.api.v2.wishlist.wrong_quantity') }, status: 422
          end
        end
      end
    end
  end
end

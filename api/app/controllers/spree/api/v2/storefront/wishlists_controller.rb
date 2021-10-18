module Spree
  module Api
    module V2
      module Storefront
        class WishlistsController < ::Spree::Api::V2::ResourceController
          before_action :require_spree_current_user, except: [:show]
          before_action :ensure_valid_quantity, only: [:add_item, :set_item_quantity]

          def show
            spree_authorize! :show, resource
            super
          end

          def create
            spree_authorize! :create, Spree::Wishlist

            @wishlist = spree_current_user.wishlists.new(wishlist_attributes)

            ensure_current_store(@wishlist)

            @wishlist.save

            if @wishlist.persisted?
              render_serialized_payload(201) { serialize_resource(@wishlist) }
            else
              render_error_payload(@wishlist.errors.full_messages.to_sentence)
            end
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
              head 204
            else
              render_error_payload(I18n.t('spree.api.v2.wishlist.errors.the_wishlist_could_not_be_destroyed'))
            end
          end

          def default
            spree_authorize! :create, Spree::Wishlist

            @default_wishlist = spree_current_user.default_wishlist_for_store(current_store)

            render_serialized_payload { serialize_resource(@default_wishlist) }
          end

          def add_item
            spree_authorize! :create, Spree::WishedItem

            if resource.wished_items.present? && resource.wished_items.detect { |wv| wv.variant_id.to_s == params[:variant_id].to_s }.present?
              @wished_item = resource.wished_items.detect { |wi| wi.variant_id.to_s == params[:variant_id].to_s }
              @wished_item.quantity = params[:quantity]
            else
              @wished_item = Spree::WishedItem.new(params.permit(:quantity, :variant_id))
              @wished_item.wishlist = resource
              @wished_item.save
            end

            resource.reload

            if @wished_item.persisted?
              render_serialized_payload { serialize_wished_item(@wished_item) }
            else
              render_error_payload(resource.errors.full_messages.to_sentence)
            end
          end

          def set_item_quantity
            spree_authorize! :update, wished_item

            wished_item.update(params.permit(:quantity))

            if wished_item.errors.empty?
              render_serialized_payload { serialize_wished_item(wished_item) }
            else
              render_error_payload(resource.errors.full_messages.to_sentence)
            end
          end

          def remove_item
            spree_authorize! :destroy, wished_item

            if wished_item.destroy
              render_serialized_payload { serialize_wished_item(wished_item) }
            else
              render_error_payload(resource.errors.full_messages.to_sentence)
            end
          end

          private

          def scope(skip_cancancan: true)
            if action_name == 'show'
              super
            else
              super.where(user: spree_current_user)
            end
          end

          def resource
            @resource ||= scope.find_by(token: params[:id])
          end

          def model_class
            Spree::Wishlist
          end

          def resource_serializer
            ::Spree::V2::Storefront::WishlistSerializer
          end

          def collection_serializer
            resource_serializer
          end

          def wishlist_attributes
            params.require(:wishlist).permit(permitted_wishlist_attributes)
          end

          def wished_item_attributes
            params.permit(permitted_wished_item_attributes)
          end

          def wished_item
            @wished_item ||= resource.wished_items.find(params[:item_id])
          end

          def serialize_wished_item(wished_item)
            ::Spree::V2::Storefront::WishedItemSerializer.new(
              wished_item,
              params: serializer_params,
              include: resource_includes,
              fields: sparse_fields
            ).serializable_hash
          end

          def serializer_params
            super.merge(is_variant_included: params[:is_variant_included])
          end

          def render_error_item_quantity
            render json: { error: I18n.t('spree.api.v2.wishlist.wrong_quantity') }, status: 422
          end

          def ensure_valid_quantity
            return render_error_item_quantity if params[:quantity].present? && params[:quantity].to_i <= 0

            params[:quantity] = if params[:quantity].present?
                                  params[:quantity].to_i
                                else
                                  1
                                end
          end
        end
      end
    end
  end
end

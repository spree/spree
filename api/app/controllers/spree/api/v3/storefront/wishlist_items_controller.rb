module Spree
  module Api
    module V3
      module Storefront
        class WishlistItemsController < ResourceController
          before_action :require_authentication!
          before_action :set_wishlist

          # GET /api/v3/storefront/wishlists/:wishlist_id/items
          def index
            render json: {
              data: serialize_collection(@wishlist.wished_items)
            }
          end

          # POST /api/v3/storefront/wishlists/:wishlist_id/items
          def create
            @item = @wishlist.wished_items.build(item_params)

            if @item.save
              render json: serialize_resource(@item), status: :created
            else
              render_errors(@item.errors)
            end
          end

          # GET /api/v3/storefront/wishlists/:wishlist_id/items/:id
          def show
            @item = @wishlist.wished_items.find(params[:id])
            render json: serialize_resource(@item)
          end

          # PATCH /api/v3/storefront/wishlists/:wishlist_id/items/:id
          def update
            @item = @wishlist.wished_items.find(params[:id])

            if @item.update(item_params)
              render json: serialize_resource(@item)
            else
              render_errors(@item.errors)
            end
          end

          # DELETE /api/v3/storefront/wishlists/:wishlist_id/items/:id
          def destroy
            @item = @wishlist.wished_items.find(params[:id])
            @item.destroy
            head :no_content
          end

          protected

          def set_wishlist
            @wishlist = current_user.wishlists.find(params[:wishlist_id])
          end

          def model_class
            Spree::WishedItem
          end

          def serializer_class
            Spree.api.v3_storefront_wished_item_serializer
          end

          def permitted_params
            item_params
          end

          def item_params
            params.require(:item).permit(Spree::PermittedAttributes.wished_item_attributes)
          end
        end
      end
    end
  end
end

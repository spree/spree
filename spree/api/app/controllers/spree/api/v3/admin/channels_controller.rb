module Spree
  module Api
    module V3
      module Admin
        class ChannelsController < ResourceController
          scoped_resource :settings

          # POST /api/v3/admin/channels/:id/add_products
          # Body: { product_ids: [...], published_at: nil, unpublished_at: nil }
          def add_products
            channel = find_resource
            authorize! :update, channel

            count = channel.add_products(
              scoped_product_ids,
              published_at: params[:published_at].presence,
              unpublished_at: params[:unpublished_at].presence
            )
            render json: { product_count: count }
          end

          # POST /api/v3/admin/channels/:id/remove_products
          # Body: { product_ids: [...] }
          def remove_products
            channel = find_resource
            authorize! :update, channel

            removed = channel.remove_products(scoped_product_ids)
            render json: { product_count: removed }
          end

          protected

          def model_class
            Spree::Channel
          end

          def serializer_class
            Spree.api.admin_channel_serializer
          end

          def scope
            super.for_store(current_store)
          end

          def permitted_params
            params.permit(:name, :code, :active, :default, :preferred_order_routing_strategy,
                          :preferred_storefront_access, :preferred_guest_checkout)
          end

          private

          # Scoped to the current store: a product can only be published to a
          # channel of the store that owns it (products are single-owner via
          # `belongs_to :store`). Foreign product IDs are silently dropped.
          def scoped_product_ids
            ids = decode_prefixed_ids(params[:product_ids])
            current_store.products.accessible_by(current_ability, :update).where(id: ids).ids
          end
        end
      end
    end
  end
end

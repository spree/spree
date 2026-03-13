module Spree
  module Api
    module V3
      module Store
        module Carts
          class ItemsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # POST  /api/v3/store/carts/:cart_id/items
            def create
              with_order_lock do
                result = Spree.cart_add_item_service.call(
                  order: @cart,
                  variant: variant,
                  quantity: permitted_params[:quantity] || 1,
                  metadata: permitted_params[:metadata] || {},
                  options: permitted_params[:options] || {}
                )

                if result.success?
                  render_cart(status: :created)
                else
                  render_service_error(result.error, code: ERROR_CODES[:insufficient_stock])
                end
              end
            end

            # PATCH  /api/v3/store/carts/:cart_id/items/:id
            def update
              with_order_lock do
                @line_item = @cart.line_items.find_by_prefix_id!(params[:id])

                @line_item.metadata = @line_item.metadata.merge(permitted_params[:metadata].to_h) if permitted_params[:metadata].present?

                if permitted_params[:quantity].present?
                  result = Spree.cart_set_item_quantity_service.call(
                    order: @cart,
                    line_item: @line_item,
                    quantity: permitted_params[:quantity]
                  )

                  if result.success?
                    render_cart
                  else
                    render_service_error(result.error, code: ERROR_CODES[:invalid_quantity])
                  end
                elsif @line_item.changed?
                  @line_item.save!
                  render_cart
                else
                  render_cart
                end
              end
            end

            # DELETE  /api/v3/store/carts/:cart_id/items/:id
            def destroy
              with_order_lock do
                @line_item = @cart.line_items.find_by_prefix_id!(params[:id])

                Spree.cart_remove_line_item_service.call(
                  order: @cart,
                  line_item: @line_item
                )

                render_cart
              end
            end

            private

            def variant
              @variant ||= current_store.variants.accessible_by(current_ability).find_by_prefix_id!(permitted_params[:variant_id])
            end

            def permitted_params
              params.permit(Spree::PermittedAttributes.line_item_attributes + [{ options: {} }])
            end
          end
        end
      end
    end
  end
end

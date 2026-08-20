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
                result = Spree.cart_add_item_workflow.call(
                  cart: @cart,
                  variant: variant,
                  quantity: permitted_params[:quantity] || 1,
                  metadata: permitted_params[:metadata] || {},
                  options: item_options
                )

                if result.success?
                  render_cart(status: :created)
                else
                  render_result_error(result)
                end
              end
            end

            # PATCH  /api/v3/store/carts/:cart_id/items/:id
            def update
              with_order_lock do
                @line_item = @cart.line_items.find_by_prefix_id!(params[:id])

                if permitted_params[:quantity].present?
                  # Zero and negatives remove the row in the upsert vocabulary,
                  # but this endpoint documents `quantity >= 1` and DELETE is
                  # how a client removes an item. Deleting on a PATCH the
                  # schema forbids would be a surprising 200.
                  if permitted_params[:quantity].to_i < 1
                    return render_error(
                      code: ERROR_CODES[:invalid_quantity],
                      message: Spree.t('cart_line_item.quantity_must_be_positive'),
                      status: :unprocessable_content
                    )
                  end

                  result = Spree.cart_upsert_items_workflow.call(
                    cart: @cart,
                    items: [{
                      variant_id: @line_item.variant_id,
                      quantity: permitted_params[:quantity],
                      metadata: permitted_params[:metadata]
                    }]
                  )

                  if result.success?
                    render_cart
                  else
                    render_result_error(result)
                  end
                else
                  # Metadata-only edit — no quantity change, so no item rules
                  # to run and nothing for the cart to recalculate.
                  if permitted_params[:metadata].present?
                    @line_item.update!(metadata: @line_item.metadata.merge(permitted_params[:metadata].to_h))
                  end

                  render_cart
                end
              end
            end

            # DELETE  /api/v3/store/carts/:cart_id/items/:id
            def destroy
              with_order_lock do
                @line_item = @cart.line_items.find_by_prefix_id!(params[:id])

                result = Spree.cart_upsert_items_workflow.call(
                  cart: @cart,
                  items: [{ variant_id: @line_item.variant_id, quantity: 0 }]
                )

                if result.success?
                  render_cart
                else
                  render_result_error(result)
                end
              end
            end

            private

            def variant
              @variant ||= current_store.variants.find_by_prefix_id!(permitted_params[:variant_id])
            end

            # Extension attributes ride in `options`, which is how AddItem
            # forwards per-line-item values onto the record.
            def item_options
              keys = Spree::LineItem.additional_permitted_attributes.flat_map { |a| a.is_a?(Hash) ? a.keys : a }
              extras = permitted_params.to_h.slice(*keys.map(&:to_s)).symbolize_keys

              (permitted_params[:options] || {}).to_h.symbolize_keys.merge(extras)
            end

            def permitted_params
              params.permit(
                :id, :variant_id, :quantity,
                *Spree::LineItem.additional_permitted_attributes,
                { metadata: {}, options: {} }
              )
            end
          end
        end
      end
    end
  end
end

module Spree
  module Api
    module V3
      module Store
        module Carts
          class ItemsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            request_params 'AddLineItemParams', action: :create do |body|
              body.attribute :variant_id, :id, required: true, example: 'variant_abc123'
              body.attribute :quantity, :integer, example: 2, description: 'Defaults to 1.'
              body.attribute :metadata, :hash,
                example: { gift_message: 'Happy Birthday!' },
                description: 'Write-only key-value metadata.'
              body.attribute :options, :hash, description: 'Values for line item attributes an extension adds.'
              body.attribute :recipient, :object, shape: Spree::Api::V3::Store::GiftCardRecipientRequestSchema,
                description: 'Who a gift card is for; only accepted when the variant is a gift card. Without it the card is emailed to the order email. Adding the same denomination for a different recipient creates a separate line.'
            end

            request_params 'UpdateLineItemParams', action: :update do |body|
              body.attribute :quantity, :integer, example: 5, description: 'At least 1. Remove an item with DELETE.'
              body.attribute :metadata, :hash,
                example: { engraving: 'J.D.' },
                description: 'Write-only key-value metadata, merged with what the line item has.'
              body.attribute :recipient, :object, shape: Spree::Api::V3::Store::GiftCardRecipientRequestSchema,
                description: 'Replaces who a gift card line is for. Only accepted on a gift card line.'
            end

            # POST  /api/v3/store/carts/:cart_id/items
            def create
              with_order_lock do
                result = Spree.cart_add_item_workflow.call(
                  cart: @cart,
                  variant: variant,
                  quantity: permitted_params[:quantity] || 1,
                  metadata: permitted_params[:metadata] || {},
                  options: item_options,
                  recipient: permitted_params[:recipient]&.to_h
                )

                if result.success?
                  sweep_unavailable_coupon_code!
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

                # Zero and negatives remove the row in the upsert vocabulary,
                # but this endpoint documents `quantity >= 1` and DELETE is
                # how a client removes an item. Deleting on a PATCH the
                # schema forbids would be a surprising 200.
                if permitted_params[:quantity].present? && permitted_params[:quantity].to_i < 1
                  return render_error(
                    code: ERROR_CODES[:invalid_quantity],
                    message: I18n.t('spree.cart_line_item.quantity_must_be_positive'),
                    status: :unprocessable_content
                  )
                end

                # Checked now and written last, so a refused request never
                # leaves a new recipient behind.
                recipient = @line_item.stage_gift_card_recipient(permitted_params[:recipient].to_h) if permitted_params[:recipient].present?
                return render_validation_error(recipient.errors) if recipient&.invalid?

                if permitted_params[:quantity].present?
                  result = Spree.cart_upsert_items_workflow.call(
                    cart: @cart,
                    items: [{
                      variant_id: @line_item.variant_id,
                      line_item_id: @line_item.id,
                      quantity: permitted_params[:quantity],
                      metadata: permitted_params[:metadata]
                    }]
                  )

                  if result.success?
                    recipient&.save!
                    sweep_unavailable_coupon_code!
                    render_cart
                  else
                    render_result_error(result)
                  end
                else
                  recipient&.save!

                  # Metadata-only edit — no quantity change, so no item rules
                  # to run and nothing for the cart to recalculate.
                  if permitted_params[:metadata].present?
                    @line_item.update!(metadata: @line_item.metadata.merge(permitted_params[:metadata].to_h))
                  end

                  sweep_unavailable_coupon_code!
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
                  items: [{ variant_id: @line_item.variant_id, line_item_id: @line_item.id, quantity: 0 }]
                )

                if result.success?
                  sweep_unavailable_coupon_code!
                  render_cart
                else
                  render_result_error(result)
                end
              end
            end

            private

            def variant
              @variant ||= @cart.orderable_variants.find_by_prefix_id!(permitted_params[:variant_id])
            end

            # Extension attributes ride in `options`, which is how AddItem
            # forwards per-line-item values onto the record. Only those reach
            # it: anything else in `options` is internal to AddItem (the
            # fulfillment an admin pins a line to) and not the shopper's to set.
            def item_options
              keys = Spree::LineItem.additional_permitted_attributes.flat_map { |a| a.is_a?(Hash) ? a.keys : a }.map(&:to_s)

              (permitted_params[:options] || {}).to_h.slice(*keys).
                merge(permitted_params.to_h.slice(*keys)).
                symbolize_keys
            end

            def permitted_params
              params.permit(*declared_permitted_attributes, *Spree::LineItem.additional_permitted_attributes)
            end
          end
        end
      end
    end
  end
end

module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Goods coming back on one of this seller's orders.
          #
          # Rooted at the order fetched through `current_seller_orders`, so a
          # return on somebody else's order reads as missing rather than
          # denied, and every id the payload names — the units returned, the
          # shelf they go back to, the reason — is resolved through the
          # seller's own records.
          #
          # Every status move reuses the operator's workflow, so restocking,
          # the tax credit, the refund and the ledger reversal all happen
          # exactly as they do when the marketplace handles the return itself.
          class ReturnsController < Seller::ResourceController
            include Spree::Api::V3::OrderLock

            # Returns are a subject of the `orders` catalog resource, so
            # `read_orders`/`write_orders` gate these endpoints. Naming
            # `:returns` here would name a key no catalog knows.
            scoped_resource :orders

            before_action :set_order
            before_action :set_resource, only: [:show, :approve, :receive, :refund, :cancel]

            # POST /api/v3/seller/orders/:order_id/returns
            def create
              authorize!(:create, Spree::Return)

              result = Spree.return_create_workflow.call(
                order: @order,
                items: items_for_create,
                stock_location: stock_location_for_create,
                reason: reason_for_create,
                memo: create_params[:memo],
                created_by: try_spree_current_user
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_result_error(result)
              end
            end

            # PATCH /api/v3/seller/orders/:order_id/returns/:id/approve
            def approve
              run_workflow(Spree.return_approve_workflow, approver: try_spree_current_user)
            end

            # PATCH /api/v3/seller/orders/:order_id/returns/:id/receive
            #
            # `items` carries what actually arrived; omitting it receives
            # everything as requested and resellable.
            def receive
              run_workflow(Spree.return_receive_workflow,
                           items: items_for_receive,
                           received_by: try_spree_current_user)
            end

            # PATCH /api/v3/seller/orders/:order_id/returns/:id/refund
            #
            # The seller took the money for their own child order, so giving it
            # back is theirs. What can be given back is bounded by the return
            # itself and, on a split checkout, by this order's share of the
            # group's payment — never a sibling's.
            def refund
              with_order_lock do
                run_workflow(Spree.return_refund_workflow,
                             amount: params[:amount],
                             refund_method: params[:refund_method] || 'original_payment',
                             refunder: try_spree_current_user)
              end
            end

            # PATCH /api/v3/seller/orders/:order_id/returns/:id/cancel
            def cancel
              run_workflow(Spree.return_cancel_workflow, reason: params[:reason])
            end

            protected

            def model_class
              Spree::Return
            end

            def serializer_class
              Spree.api.seller_return_serializer
            end

            def parent_association
              :returns
            end

            def read_actions
              %w[index show]
            end

            def collection_includes
              [:reason, :stock_location, { return_line_items: [:variant, :line_item] }]
            end

            private

            def set_order
              @order = @parent = current_seller_orders.find_by_prefix_id!(params[:order_id])
              authorize! :show, @order
            end

            def run_workflow(workflow, **arguments)
              result = workflow.call(return_record: @resource, **arguments)

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_result_error(result)
              end
            end

            def create_params
              @create_params ||= params.permit(:memo, :reason_id, :stock_location_id,
                                               items: [:fulfillment_item_id, :quantity])
            end

            # Addressed by fulfillment item and resolved through the order, so
            # units belonging to another seller's order cannot be returned here.
            def items_for_create
              Array(create_params[:items]).map do |item|
                {
                  fulfillment_item: @order.fulfillment_items.find_by_prefix_id!(item[:fulfillment_item_id]),
                  quantity: item[:quantity].to_i
                }
              end
            end

            def items_for_receive
              return nil if params[:items].blank?

              params.permit(items: [:return_line_item_id, :quantity, :resellable])[:items].map do |item|
                {
                  return_line_item: @resource.return_line_items.find_by_prefix_id!(item[:return_line_item_id]),
                  quantity: item[:quantity].to_i,
                  resellable: item.key?(:resellable) ? item[:resellable].to_b : true
                }
              end
            end

            # The seller's own shelves only — goods coming back to a
            # marketplace warehouse is not this endpoint's business.
            def stock_location_for_create
              return nil if create_params[:stock_location_id].blank?

              current_seller.stock_locations.find_by_prefix_id!(create_params[:stock_location_id])
            end

            def reason_for_create
              return nil if create_params[:reason_id].blank?

              current_store.return_reasons.find_by_prefix_id!(create_params[:reason_id])
            end
          end
        end
      end
    end
  end
end

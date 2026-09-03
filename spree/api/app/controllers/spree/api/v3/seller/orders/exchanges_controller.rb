module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Swapping goods on one of this seller's orders — a different size,
          # colour or product.
          #
          # Rooted at the order fetched through `current_seller_orders`. The
          # replacement variant is resolved through `current_seller.variants`
          # rather than the store's: a seller exchanges into their own
          # catalogue, and reaching a rival's variant here would put that
          # seller's stock on this seller's order.
          class ExchangesController < Seller::ResourceController
            include Spree::Api::V3::OrderLock

            # Exchanges are a subject of the `orders` catalog resource.
            scoped_resource :orders

            before_action :set_order
            before_action :set_resource, only: [:show, :approve, :receive, :fulfill, :cancel]

            # POST /api/v3/seller/orders/:order_id/exchanges
            def create
              authorize!(:create, Spree::Exchange)

              result = Spree.exchange_create_workflow.call(
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

            # PATCH /api/v3/seller/orders/:order_id/exchanges/:id/approve
            def approve
              run_workflow(Spree.exchange_approve_workflow, approver: try_spree_current_user)
            end

            # PATCH /api/v3/seller/orders/:order_id/exchanges/:id/receive
            def receive
              run_workflow(Spree.exchange_receive_workflow,
                           items: items_for_receive,
                           received_by: try_spree_current_user)
            end

            # PATCH /api/v3/seller/orders/:order_id/exchanges/:id/fulfill
            #
            # Sends the replacement. Settles a price difference at the same
            # time, which is why it takes a refund method.
            def fulfill
              with_order_lock do
                run_workflow(Spree.exchange_fulfill_workflow,
                             refund_method: params[:refund_method] || 'store_credit',
                             refunder: try_spree_current_user)
              end
            end

            # PATCH /api/v3/seller/orders/:order_id/exchanges/:id/cancel
            def cancel
              run_workflow(Spree.exchange_cancel_workflow, reason: params[:reason])
            end

            protected

            def model_class
              Spree::Exchange
            end

            def serializer_class
              Spree.api.seller_exchange_serializer
            end

            def parent_association
              :exchanges
            end

            def read_actions
              %w[index show]
            end

            def collection_includes
              [:reason, :stock_location, { exchange_line_items: [:variant, :new_variant, :line_item] }]
            end

            private

            def set_order
              @order = @parent = current_seller_orders.find_by_prefix_id!(params[:order_id])
              authorize! :show, @order
            end

            def run_workflow(workflow, **arguments)
              result = workflow.call(exchange: @resource, **arguments)

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_result_error(result)
              end
            end

            def create_params
              @create_params ||= params.permit(:memo, :reason_id, :stock_location_id,
                                               items: [:fulfillment_item_id, :new_variant_id, :quantity])
            end

            def items_for_create
              Array(create_params[:items]).map do |item|
                {
                  fulfillment_item: @order.fulfillment_items.find_by_prefix_id!(item[:fulfillment_item_id]),
                  new_variant: current_seller.variants.find_by_prefix_id!(item[:new_variant_id]),
                  quantity: item[:quantity].to_i
                }
              end
            end

            def items_for_receive
              return nil if params[:items].blank?

              params.permit(items: [:exchange_line_item_id, :quantity, :resellable])[:items].map do |item|
                {
                  exchange_line_item: @resource.exchange_line_items.find_by_prefix_id!(item[:exchange_line_item_id]),
                  quantity: item[:quantity].to_i,
                  resellable: item.key?(:resellable) ? item[:resellable].to_b : true
                }
              end
            end

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

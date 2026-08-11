module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Exchanges on a completed order. Each status change is its own
          # member action, because each carries different arguments.
          class ExchangesController < BaseController
            # Exchanges are a subject of the `orders` catalog resource, so
            # `read_orders`/`write_orders` gate these endpoints. `:exchanges`
            # would name a key no catalog knows.
            scoped_resource :orders

            before_action :set_resource, only: [:show, :update, :approve, :receive, :fulfill, :cancel]

            # POST /api/v3/admin/orders/:order_id/exchanges
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

            # PATCH /api/v3/admin/orders/:order_id/exchanges/:id
            def update
              if @resource.update(permitted_params)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/exchanges/:id/approve
            def approve
              run_workflow(Spree.exchange_approve_workflow, approver: try_spree_current_user)
            end

            # PATCH /api/v3/admin/orders/:order_id/exchanges/:id/receive
            def receive
              run_workflow(Spree.exchange_receive_workflow,
                           items: items_for_receive,
                           received_by: try_spree_current_user)
            end

            # PATCH /api/v3/admin/orders/:order_id/exchanges/:id/fulfill
            def fulfill
              run_workflow(Spree.exchange_fulfill_workflow,
                           refund_method: params[:refund_method] || 'store_credit',
                           refunder: try_spree_current_user)
            end

            # PATCH /api/v3/admin/orders/:order_id/exchanges/:id/cancel
            def cancel
              run_workflow(Spree.exchange_cancel_workflow, reason: params[:reason])
            end

            protected

            def model_class
              Spree::Exchange
            end

            def serializer_class
              Spree.api.admin_exchange_serializer
            end

            def parent_association
              :exchanges
            end

            def collection_includes
              [:reason, :stock_location, { exchange_line_items: [:original_variant, :new_variant] }]
            end

            def permitted_params
              params.permit(:memo, :reason_id, :stock_location_id, metadata: {})
            end

            def create_params
              @create_params ||= params.permit(:memo, :reason_id, :stock_location_id,
                                               items: [:fulfillment_item_id, :new_variant_id, :quantity])
            end

            private

            def run_workflow(workflow, **arguments)
              result = workflow.call(exchange: @resource, **arguments)

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_result_error(result)
              end
            end

            def items_for_create
              Array(create_params[:items]).map do |item|
                {
                  fulfillment_item: @order.fulfillment_items.find_by_prefix_id!(item[:fulfillment_item_id]),
                  new_variant: current_store.variants.find_by_prefix_id!(item[:new_variant_id]),
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
                  resellable: item.key?(:resellable) ? ActiveModel::Type::Boolean.new.cast(item[:resellable]) : true
                }
              end
            end

            def stock_location_for_create
              return nil if create_params[:stock_location_id].blank?

              current_store.stock_locations.accessible_by(current_ability, :show).
                find_by_prefix_id!(create_params[:stock_location_id])
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

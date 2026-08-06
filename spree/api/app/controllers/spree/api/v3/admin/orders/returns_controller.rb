module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Returns on a completed order. Every status change goes through its
          # own member action rather than mass assignment, because each one is
          # a workflow with its own arguments — receiving carries the
          # quantities the warehouse counted, refunding carries a method and
          # an amount.
          class ReturnsController < BaseController
            scoped_resource :returns

            before_action :set_resource, only: [:show, :update, :approve, :receive, :refund, :cancel]

            # POST /api/v3/admin/orders/:order_id/returns
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

            # PATCH /api/v3/admin/orders/:order_id/returns/:id
            #
            # Editable fields only — status moves through the member actions.
            def update
              if @resource.update(permitted_params)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/returns/:id/approve
            def approve
              run_workflow(Spree.return_approve_workflow, approver: try_spree_current_user)
            end

            # PATCH /api/v3/admin/orders/:order_id/returns/:id/receive
            #
            # `items` carries what actually arrived; omitting it receives
            # everything as requested and resellable.
            def receive
              run_workflow(Spree.return_receive_workflow,
                           items: items_for_receive,
                           received_by: try_spree_current_user)
            end

            # PATCH /api/v3/admin/orders/:order_id/returns/:id/refund
            def refund
              run_workflow(Spree.return_refund_workflow,
                           amount: params[:amount],
                           refund_method: params[:refund_method] || 'original_payment',
                           refunder: try_spree_current_user)
            end

            # PATCH /api/v3/admin/orders/:order_id/returns/:id/cancel
            def cancel
              run_workflow(Spree.return_cancel_workflow, reason: params[:reason])
            end

            protected

            def model_class
              Spree::Return
            end

            def serializer_class
              Spree.api.admin_return_serializer
            end

            def parent_association
              :returns
            end

            def collection_includes
              [:reason, :stock_location, { return_line_items: [:variant, :line_item] }]
            end

            def permitted_params
              params.permit(:memo, :reason_id, :stock_location_id, metadata: {})
            end

            def create_params
              @create_params ||= params.permit(:memo, :reason_id, :stock_location_id,
                                               items: [:fulfillment_item_id, :quantity])
            end

            private

            def run_workflow(workflow, **arguments)
              result = workflow.call(return_record: @resource, **arguments)

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

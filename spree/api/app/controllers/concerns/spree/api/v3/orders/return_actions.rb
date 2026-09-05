module Spree
  module Api
    module V3
      module Orders
        # Goods coming back on an order: opening the return, and the four
        # moves that settle it.
        #
        # See {PostSaleActions} for why the lookups a payload's ids resolve
        # through are deliberately left to the including controller.
        module ReturnActions
          extend ActiveSupport::Concern
          include PostSaleActions

          # POST .../returns
          def create
            create_post_sale_record(
              Spree.return_create_workflow, Spree::Return,
              stock_location: stock_location_for_create
            )
          end

          # PATCH .../returns/:id/approve
          def approve
            run_workflow(Spree.return_approve_workflow, approver: try_spree_current_user)
          end

          # PATCH .../returns/:id/receive — what the warehouse actually counted.
          def receive
            run_workflow(Spree.return_receive_workflow,
                         items: items_for_receive,
                         received_by: try_spree_current_user)
          end

          # PATCH .../returns/:id/refund
          def refund
            run_workflow(Spree.return_refund_workflow,
                         amount: params[:amount],
                         refund_method: params[:refund_method] || 'original_payment',
                         refunder: try_spree_current_user)
          end

          # PATCH .../returns/:id/cancel
          def cancel
            run_workflow(Spree.return_cancel_workflow, reason: params[:reason])
          end

          protected

          def model_class
            Spree::Return
          end

          def parent_association
            :returns
          end

          def workflow_record_key
            :return_record
          end

          private

          def create_params
            @create_params ||= params.permit(
              :memo, :reason_id, :stock_location_id,
              items: [:fulfillment_item_id, :quantity]
            )
          end

          # The units coming back, resolved through the order itself, so a
          # fulfillment item from another order cannot be returned against
          # this one.
          def items_for_create
            Array(create_params[:items]).map do |item|
              {
                fulfillment_item: @order.fulfillment_items.find_by_prefix_id!(item[:fulfillment_item_id]),
                quantity: item[:quantity].to_i
              }
            end
          end

          # What the warehouse counted, resolved through the return itself.
          def items_for_receive
            # `nil` means "receive it all as requested"; an empty list means
            # the caller named no units, which must not fall through to that.
            return nil unless params.key?(:items)

            params.permit(items: [:return_line_item_id, :quantity, :resellable])[:items].map do |item|
              {
                return_line_item: @resource.return_line_items.find_by_prefix_id!(item[:return_line_item_id]),
                quantity: item[:quantity].to_i,
                resellable: item.key?(:resellable) ? item[:resellable].to_b : true
              }
            end
          end

          # The merchant's own vocabulary either way: a seller picks a reason,
          # the operator decides what the reasons are.
          def reason_for_create
            return nil if create_params[:reason_id].blank?

            current_store.return_reasons.find_by_prefix_id!(create_params[:reason_id])
          end

          # The shelf the goods go back to — the store's warehouses for an
          # operator, only their own for a seller. Left to the including
          # controller because it decides whose stock this restocks.
          #
          # @return [Spree::StockLocation, nil]
          def stock_location_for_create
            raise NotImplementedError, "#{self.class} must implement #stock_location_for_create"
          end
        end
      end
    end
  end
end

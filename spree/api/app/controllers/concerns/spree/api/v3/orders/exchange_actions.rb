module Spree
  module Api
    module V3
      module Orders
        # Swapping goods on an order — a different size, colour or product —
        # and the four moves that settle it.
        #
        # See {PostSaleActions} for why the lookups a payload's ids resolve
        # through are deliberately left to the including controller.
        module ExchangeActions
          extend ActiveSupport::Concern
          include PostSaleActions

          # POST .../exchanges
          def create
            create_post_sale_record(
              Spree.exchange_create_workflow, Spree::Exchange,
              stock_location: stock_location_for_create
            )
          end

          # PATCH .../exchanges/:id/approve
          def approve
            run_workflow(Spree.exchange_approve_workflow, approver: try_spree_current_user)
          end

          # PATCH .../exchanges/:id/receive
          def receive
            run_workflow(Spree.exchange_receive_workflow,
                         items: items_for_receive,
                         received_by: try_spree_current_user)
          end

          # PATCH .../exchanges/:id/fulfill — sends the replacement, settling
          # any price difference, which is why it takes a refund method.
          def fulfill
            run_workflow(Spree.exchange_fulfill_workflow,
                         refund_method: params[:refund_method] || 'store_credit',
                         refunder: try_spree_current_user)
          end

          # PATCH .../exchanges/:id/cancel
          def cancel
            run_workflow(Spree.exchange_cancel_workflow, reason: params[:reason])
          end

          protected

          def model_class
            Spree::Exchange
          end

          def parent_association
            :exchanges
          end

          def workflow_record_key
            :exchange
          end

          private

          def create_params
            @create_params ||= params.permit(
              :memo, :reason_id, :stock_location_id,
              items: [:fulfillment_item_id, :new_variant_id, :quantity]
            )
          end

          # The units going back are resolved through the order; what comes
          # out instead is resolved through {#replacement_variant_for}.
          def items_for_create
            Array(create_params[:items]).map do |item|
              {
                fulfillment_item: @order.fulfillment_items.find_by_prefix_id!(item[:fulfillment_item_id]),
                new_variant: replacement_variant_for(item[:new_variant_id]),
                quantity: item[:quantity].to_i
              }
            end
          end

          def items_for_receive
            sent = received_items([:exchange_line_item_id, :quantity, :resellable])
            return nil if sent.nil?

            sent.map do |item|
              {
                exchange_line_item: @resource.exchange_line_items.find_by_prefix_id!(item[:exchange_line_item_id]),
                quantity: item[:quantity].to_i,
                resellable: item.key?(:resellable) ? item[:resellable].to_b : true
              }
            end
          end

          def reason_for_create
            return nil if create_params[:reason_id].blank?

            current_store.return_reasons.find_by_prefix_id!(create_params[:reason_id])
          end

          # The catalogue the replacement comes out of, and the shelf the
          # returned goods go back to. Both are left to the including
          # controller: an operator exchanges into the whole store, a seller
          # only into their own goods, and getting this wrong would put one
          # seller's stock on another's order.
          def replacement_variant_for(_variant_id)
            raise NotImplementedError, "#{self.class} must implement #replacement_variant_for"
          end

          def stock_location_for_create
            raise NotImplementedError, "#{self.class} must implement #stock_location_for_create"
          end
        end
      end
    end
  end
end

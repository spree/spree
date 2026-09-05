module Spree
  module Api
    module V3
      module Orders
        # Something went wrong with a delivery, and the merchant makes it
        # right — money back, a replacement, or both — without necessarily
        # asking for the goods back.
        #
        # See {PostSaleActions} for why the lookups a payload's ids resolve
        # through are deliberately left to the including controller.
        module ClaimActions
          extend ActiveSupport::Concern
          include PostSaleActions

          # POST .../claims
          def create
            create_post_sale_record(Spree.claim_create_workflow, Spree::Claim)
          end

          # PATCH .../claims/:id/approve
          def approve
            run_workflow(Spree.claim_approve_workflow, approver: try_spree_current_user)
          end

          # PATCH .../claims/:id/resolve — a refund, a replacement, or both.
          def resolve
            run_workflow(Spree.claim_resolve_workflow,
                         resolution: params[:resolution],
                         refund_method: params[:refund_method] || 'store_credit',
                         amount: params[:amount],
                         replacement_line_item_ids: replacement_line_item_ids,
                         resolver: try_spree_current_user)
          end

          # PATCH .../claims/:id/deny
          def deny
            run_workflow(Spree.claim_deny_workflow, reason: params[:reason])
          end

          # PATCH .../claims/:id/cancel
          def cancel
            run_workflow(Spree.claim_cancel_workflow, reason: params[:reason])
          end

          protected

          def model_class
            Spree::Claim
          end

          def parent_association
            :claims
          end

          def workflow_record_key
            :claim
          end

          private

          def create_params
            @create_params ||= params.permit(
              :memo, :reason_id,
              items: [:line_item_id, :quantity, :description, :send_replacement,
                      :replacement_variant_id, :refund_amount]
            )
          end

          # Every claimed line is resolved through the order itself, so a line
          # item from another order cannot be claimed against this one.
          def items_for_create
            Array(create_params[:items]).map do |item|
              {
                line_item: @order.line_items.find_by_prefix_id!(item[:line_item_id]),
                quantity: item[:quantity].to_i,
                description: item[:description],
                send_replacement: item[:send_replacement].to_b,
                replacement_variant: replacement_variant_for(item[:replacement_variant_id]),
                refund_amount: item[:refund_amount]
              }
            end
          end

          # Which lines to replace, decided at resolution time. Absent means
          # "leave whatever the claim was opened with".
          def replacement_line_item_ids
            return nil unless params.key?(:replacement_line_item_ids)

            Array(params[:replacement_line_item_ids]).map do |id|
              @resource.claim_line_items.find_by_prefix_id!(id).id
            end
          end

          def reason_for_create
            return nil if create_params[:reason_id].blank?

            current_store.claim_reasons.find_by_prefix_id!(create_params[:reason_id])
          end

          # The catalogue a replacement may be promised from. Left to the
          # including controller precisely because getting it wrong would let
          # one seller ship another's stock.
          #
          # @return [Spree::Variant, nil]
          def replacement_variant_for(_variant_id)
            raise NotImplementedError, "#{self.class} must implement #replacement_variant_for"
          end
        end
      end
    end
  end
end

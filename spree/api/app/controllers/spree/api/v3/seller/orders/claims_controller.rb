module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Something went wrong with a delivery on one of this seller's
          # orders, and the seller makes it right — money back, a replacement,
          # or both — without necessarily asking for the goods back.
          #
          # Rooted at the order fetched through `current_seller_orders`, with
          # the claimed lines and any replacement variant resolved through the
          # order and the seller's own catalogue.
          class ClaimsController < Seller::ResourceController
            include Spree::Api::V3::OrderLock

            # Claims are a subject of the `orders` catalog resource.
            scoped_resource :orders

            before_action :set_order
            before_action :set_resource, only: [:show, :approve, :resolve, :deny, :cancel]

            # POST /api/v3/seller/orders/:order_id/claims
            def create
              authorize!(:create, Spree::Claim)

              result = Spree.claim_create_workflow.call(
                order: @order,
                items: items_for_create,
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

            # PATCH /api/v3/seller/orders/:order_id/claims/:id/approve
            def approve
              run_workflow(Spree.claim_approve_workflow, approver: try_spree_current_user)
            end

            # PATCH /api/v3/seller/orders/:order_id/claims/:id/resolve
            #
            # Settles the claim: a refund, a replacement shipment, or both.
            def resolve
              with_order_lock do
                run_workflow(Spree.claim_resolve_workflow,
                             resolution: params[:resolution],
                             refund_method: params[:refund_method] || 'store_credit',
                             amount: params[:amount],
                             replacement_line_item_ids: replacement_line_item_ids,
                             resolver: try_spree_current_user)
              end
            end

            # PATCH /api/v3/seller/orders/:order_id/claims/:id/deny
            def deny
              run_workflow(Spree.claim_deny_workflow, reason: params[:reason])
            end

            # PATCH /api/v3/seller/orders/:order_id/claims/:id/cancel
            def cancel
              run_workflow(Spree.claim_cancel_workflow, reason: params[:reason])
            end

            protected

            def model_class
              Spree::Claim
            end

            def serializer_class
              Spree.api.seller_claim_serializer
            end

            def parent_association
              :claims
            end

            def read_actions
              %w[index show]
            end

            def collection_includes
              [:reason, { claim_line_items: [:variant, :line_item, :replacement_variant] }]
            end

            private

            def set_order
              @order = @parent = current_seller_orders.find_by_prefix_id!(params[:order_id])
              authorize! :show, @order
            end

            def run_workflow(workflow, **arguments)
              result = workflow.call(claim: @resource, **arguments)

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_result_error(result)
              end
            end

            def create_params
              @create_params ||= params.permit(
                :memo, :reason_id,
                items: [:line_item_id, :quantity, :description, :send_replacement,
                        :replacement_variant_id, :refund_amount]
              )
            end

            def items_for_create
              Array(create_params[:items]).map do |item|
                {
                  line_item: @order.line_items.find_by_prefix_id!(item[:line_item_id]),
                  quantity: item[:quantity].to_i,
                  description: item[:description],
                  send_replacement: item[:send_replacement].to_b,
                  replacement_variant: replacement_variant_for(item),
                  refund_amount: item[:refund_amount]
                }
              end
            end

            # The seller's own catalogue: a replacement is stock this seller
            # sends, so a variant belonging to another seller is not theirs to
            # promise.
            def replacement_variant_for(item)
              return nil if item[:replacement_variant_id].blank?

              current_seller.variants.find_by_prefix_id!(item[:replacement_variant_id])
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
          end
        end
      end
    end
  end
end

module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Claims on a completed order.
          class ClaimsController < BaseController
            scoped_resource :claims

            before_action :set_resource, only: [:show, :update, :approve, :resolve, :deny, :cancel]

            # POST /api/v3/admin/orders/:order_id/claims
            def create
              authorize!(:create, Spree::Claim)

              result = Spree.claim_create_workflow.call(
                order: @order,
                items: items_for_create,
                claim_type: create_params[:claim_type] || 'other',
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

            # PATCH /api/v3/admin/orders/:order_id/claims/:id
            def update
              if @resource.update(permitted_params)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/claims/:id/approve
            def approve
              run_workflow(Spree.claim_approve_workflow, approver: try_spree_current_user)
            end

            # PATCH /api/v3/admin/orders/:order_id/claims/:id/resolve
            #
            # The resolution is chosen here rather than at claim creation, so
            # an admin decides how to make things right once they have the
            # facts.
            def resolve
              run_workflow(Spree.claim_resolve_workflow,
                           resolution: params[:resolution],
                           refund_method: params[:refund_method] || 'store_credit',
                           amount: params[:amount],
                           replacement_line_item_ids: replacement_line_item_ids,
                           resolver: try_spree_current_user)
            end

            # PATCH /api/v3/admin/orders/:order_id/claims/:id/deny
            def deny
              run_workflow(Spree.claim_deny_workflow, reason: params[:reason])
            end

            # PATCH /api/v3/admin/orders/:order_id/claims/:id/cancel
            def cancel
              run_workflow(Spree.claim_cancel_workflow, reason: params[:reason])
            end

            protected

            def model_class
              Spree::Claim
            end

            def serializer_class
              Spree.api.admin_claim_serializer
            end

            def parent_association
              :claims
            end

            def collection_includes
              [:reason, { claim_line_items: [:variant, :replacement_variant] }]
            end

            def permitted_params
              params.permit(:memo, :reason_id, :claim_type, metadata: {})
            end

            def create_params
              @create_params ||= params.permit(
                :memo, :reason_id, :claim_type,
                items: [:line_item_id, :quantity, :description, :send_replacement,
                        :replacement_variant_id, :refund_amount]
              )
            end

            private

            # Which lines to replace, decided at resolution time. Absent means
            # "leave whatever the claim was opened with".
            def replacement_line_item_ids
              return nil unless params.key?(:replacement_line_item_ids)

              Array(params[:replacement_line_item_ids]).map do |id|
                @resource.claim_line_items.find_by_prefix_id!(id).id
              end
            end

            def run_workflow(workflow, **arguments)
              result = workflow.call(claim: @resource, **arguments)

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_result_error(result)
              end
            end

            def items_for_create
              Array(create_params[:items]).map do |item|
                {
                  line_item: @order.line_items.find_by_prefix_id!(item[:line_item_id]),
                  quantity: item[:quantity].to_i,
                  description: item[:description],
                  send_replacement: ActiveModel::Type::Boolean.new.cast(item[:send_replacement]),
                  replacement_variant: replacement_variant_for(item),
                  refund_amount: item[:refund_amount]
                }
              end
            end

            def replacement_variant_for(item)
              return nil if item[:replacement_variant_id].blank?

              current_store.variants.find_by_prefix_id!(item[:replacement_variant_id])
            end

            def reason_for_create
              return nil if create_params[:reason_id].blank?

              Spree::ClaimReason.find_by_prefix_id!(create_params[:reason_id])
            end
          end
        end
      end
    end
  end
end

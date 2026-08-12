module Spree
  module Api
    module V3
      module Admin
        module Orders
          class RefundsController < BaseController
            scoped_resource :refunds

            # POST /api/v3/admin/orders/:order_id/refunds
            #
            # Deliberately not wrapped in with_order_lock: the workflow calls
            # the gateway from an external_step, and holding a row lock across
            # a network round trip is exactly what that boundary exists to
            # prevent. Refund#perform! is a no-op on a credited refund, so a
            # double submit cannot credit twice.
            def create
              payment = @parent.payments.accessible_by(current_ability, :update).find_by_prefix_id!(params[:payment_id])
              reason = Spree::RefundReason.accessible_by(current_ability, :show).find_by_prefix_id!(params[:refund_reason_id]) if params[:refund_reason_id].present?
              reason ||= Spree::RefundReason.accessible_by(current_ability, :show).first

              authorize_resource!(payment.refunds.build(amount: params[:amount], reason: reason), :create)

              result = Spree.refund_create_workflow.call(
                payment: payment,
                amount: params[:amount],
                reason: reason,
                refunder: try_spree_current_user
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_result_error(result)
              end
            end

            protected

            def model_class
              Spree::Refund
            end

            def serializer_class
              Spree.api.admin_refund_serializer
            end

            def scope
              Spree::Refund.where(payment_id: @parent.payment_ids)
            end

            def collection_includes
              [:payment, :reason]
            end
          end
        end
      end
    end
  end
end

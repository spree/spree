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
              payment = settlement_payments.accessible_by(current_ability, :update).find_by_prefix_id!(params[:payment_id])
              # Scoped to the store, not just the ability — a reason id from
              # another store must 404, not attach.
              reason = current_store.refund_reasons.accessible_by(current_ability, :show).find_by_prefix_id!(params[:refund_reason_id]) if params[:refund_reason_id].present?
              reason ||= current_store.refund_reasons.accessible_by(current_ability, :show).first

              authorize_resource!(payment.refunds.build(amount: params[:amount], reason: reason), :create)

              result = Spree.refund_create_workflow.call(
                payment: payment,
                amount: params[:amount],
                reason: reason,
                refunder: try_spree_current_user,
                # Names which order is being refunded. Only matters when the
                # payment is shared by a split checkout, where it covers several
                # and the payment cannot say which one this is for.
                order: @parent
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

            # Every refund names the order it put right, so this reads the same
            # for an ordinary order and for one placed in a split checkout,
            # whose payments belong to its group rather than to itself.
            def scope
              Spree::Refund.where(order_id: @parent.id)
            end

            # The payments that can settle this order — its own, or its group's
            # when it was placed alongside others.
            def settlement_payments
              @parent.settlement_payments
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

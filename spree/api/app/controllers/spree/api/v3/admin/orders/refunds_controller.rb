module Spree
  module Api
    module V3
      module Admin
        module Orders
          class RefundsController < BaseController
            # POST /api/v3/admin/orders/:order_id/refunds
            def create
              with_order_lock do
                payment = @parent.payments.find_by_prefix_id!(params[:payment_id])
                reason = Spree::RefundReason.find_by_prefix_id!(params[:refund_reason_id]) if params[:refund_reason_id].present?
                reason ||= Spree::RefundReason.first

                @resource = payment.refunds.build(
                  amount: params[:amount],
                  reason: reason,
                  transaction_id: nil
                )
                authorize_resource!(@resource, :create)

                if @resource.save
                  render json: serialize_resource(@resource), status: :created
                else
                  render_validation_error(@resource.errors)
                end
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

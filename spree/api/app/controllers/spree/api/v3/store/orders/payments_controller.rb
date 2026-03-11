module Spree
  module Api
    module V3
      module Store
        module Orders
          class PaymentsController < Store::BaseController
            include Spree::Api::V3::OrderConcern
            include Spree::Api::V3::ResourceSerializer

            before_action :set_parent
            before_action :set_payment, only: [:show]

            # GET /api/v3/store/orders/:order_id/payments
            def index
              payments = @parent.payments.includes(:payment_method)
              render json: {
                data: serialize_payments(payments),
                meta: {}
              }
            end

            # GET /api/v3/store/orders/:order_id/payments/:id
            def show
              render json: serialize_resource(@payment)
            end

            # POST /api/v3/store/orders/:order_id/payments
            # Creates a payment for non-session payment methods (e.g. Check, Cash on Delivery, Bank Transfer)
            def create
              payment_method = current_store.payment_methods.find_by_prefix_id!(params[:payment_method_id])

              if payment_method.session_required?
                return render_error(
                  code: 'payment_session_required',
                  message: Spree.t('api.v3.payments.session_required'),
                  status: :unprocessable_content
                )
              end

              unless payment_method.available_for_order?(@parent)
                return render_error(
                  code: 'payment_method_unavailable',
                  message: Spree.t('api.v3.payments.method_unavailable'),
                  status: :unprocessable_content
                )
              end

              amount = params[:amount].presence || @parent.total_minus_store_credits

              @payment = @parent.payments.build(
                payment_method: payment_method,
                amount: amount,
                metadata: params[:metadata].present? ? params[:metadata].to_unsafe_h : {}
              )

              authorize!(:update, @parent, order_token)

              if @payment.save
                render json: serialize_resource(@payment), status: :created
              else
                render_errors(@payment.errors)
              end
            end

            private

            def set_payment
              @payment = @parent.payments.find_by_prefix_id!(params[:id])
            end

            def serializer_class
              Spree.api.payment_serializer
            end

            def serialize_payments(payments)
              payments.map { |p| serializer_class.new(p, params: serializer_params).to_h }
            end
          end
        end
      end
    end
  end
end

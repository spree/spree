module Spree
  module Api
    module V3
      module Store
        module Orders
          class PaymentsController < Store::BaseController
            include Spree::Api::V3::OrderConcern
            include Spree::Api::V3::ResourceSerializer

            before_action :set_order
            before_action :set_payment, only: [:show]

            # GET /api/v3/store/orders/:order_id/payments
            def index
              payments = @order.payments.includes(:payment_method)
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
            def create
              result = create_payment_service.call(order: @order, params: payment_params)

              if result.success?
                render json: serialize_order(@order.reload), status: :created
              else
                render_service_error(result.error)
              end
            end

            protected

            def set_order
              @order = current_store.orders.friendly.find(params[:order_id])
              authorize!(:update, @order, order_token)
            end

            def set_payment
              @payment = @order.payments.find_by!(prefix_id: params[:id])
            end

            def payment_params
              params.permit(
                :payment_method_id,
                :amount,
                source_attributes: Spree::PermittedAttributes.source_attributes
              )
            end

            def create_payment_service
              Spree::Api::Dependencies.storefront_payment_create_service.constantize
            end

            def serializer_class
              Spree.api.payment_serializer
            end

            def serialize_payments(payments)
              payments.map { |p| serializer_class.new(p, params: serializer_params).to_h }
            end

            def serialize_order(order)
              Spree.api.order_serializer.new(order, params: serializer_params).to_h
            end
          end
        end
      end
    end
  end
end

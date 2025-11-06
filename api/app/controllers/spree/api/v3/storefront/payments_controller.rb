module Spree
  module Api
    module V3
      module Storefront
        class PaymentsController < ResourceController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!
          before_action :set_payment, only: [:show]

          # GET /api/v3/storefront/orders/:order_id/payments
          def index
            render json: {
              data: serialize_collection(@order.payments.valid)
            }
          end

          # GET /api/v3/storefront/orders/:order_id/payments/:id
          def show
            render json: serialize_resource(@payment)
          end

          # POST /api/v3/storefront/orders/:order_id/payments
          def create
            @payment = @order.payments.build(payment_params)
            authorize_resource!(@payment, :create)

            if @payment.save
              render json: serialize_resource(@payment), status: :created
            else
              render_errors(@payment.errors)
            end
          end

          protected

          def set_payment
            @payment = @order.payments.valid.find(params[:id])
          end

          def model_class
            Spree::Payment
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_payment_serializer.constantize
          end

          def permitted_params
            params.require(:payment).permit(Spree::PermittedAttributes.payment_attributes)
          end
        end
      end
    end
  end
end

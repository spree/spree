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

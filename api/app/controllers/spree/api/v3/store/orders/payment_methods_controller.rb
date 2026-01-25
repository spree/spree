module Spree
  module Api
    module V3
      module Store
        module Orders
          class PaymentMethodsController < Store::BaseController
            include Spree::Api::V3::OrderConcern

            before_action :set_order, only: [:index]

            # GET /api/v3/store/orders/:order_id/payment_methods
            # Returns available payment methods for the current order
            def index
              payment_methods = @order.collect_frontend_payment_methods
              render json: {
                data: serialize_collection(payment_methods),
                meta: { count: payment_methods.size }
              }
            end

            protected

            def set_order
              @order = current_store.orders.friendly.find(params[:order_id])
              # Order access is verified through order ownership or token
              unless can?(:show, @order) || order_token == @order.token
                raise CanCan::AccessDenied, 'You are not authorized to access this page.'
              end
            end

            def serializer_class
              Spree.api.payment_method_serializer
            end

            def serialize_collection(collection)
              collection.map { |item| serializer_class.new(item, params: serializer_params).to_h }
            end

            def serializer_params
              {
                currency: current_currency,
                store: current_store,
                user: current_user
              }
            end
          end
        end
      end
    end
  end
end

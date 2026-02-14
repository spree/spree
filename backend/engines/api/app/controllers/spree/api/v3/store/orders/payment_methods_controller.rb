module Spree
  module Api
    module V3
      module Store
        module Orders
          class PaymentMethodsController < Store::BaseController
            include Spree::Api::V3::OrderConcern

            before_action :set_parent

            # GET /api/v3/store/orders/:order_id/payment_methods
            # Returns available payment methods for the current order
            def index
              payment_methods = @parent.collect_frontend_payment_methods
              render json: {
                data: serialize_collection(payment_methods),
                meta: { count: payment_methods.size }
              }
            end

            protected

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

module Spree
  module Api
    module V3
      module Storefront
        class PaymentMethodsController < BaseController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!

          # GET /api/v3/storefront/orders/:order_id/payment_methods
          def index
            @payment_methods = available_payment_methods

            render json: {
              data: serialize_collection(@payment_methods)
            }
          end

          protected

          def available_payment_methods
            @order.available_payment_methods
          end

          def serialize_collection(collection)
            collection.map { |item| serializer_class.new(item, params: serializer_params).to_h }
          end

          def serializer_class
            Spree.api.v3_storefront_payment_method_serializer
          end

          def serializer_params
            {
              currency: current_currency,
              store: current_store,
              locale: current_locale,
              includes: include_tree
            }
          end
        end
      end
    end
  end
end

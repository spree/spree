module Spree
  module Api
    module V3
      module Store
        module Checkout
          class PaymentMethodsController < Store::BaseController
            include Spree::Api::V3::CartResolvable

            before_action :find_cart!

            # GET /api/v3/store/checkout/payment_methods
            def index
              methods = @cart.collect_frontend_payment_methods
              render json: {
                data: methods.map { |m| Spree.api.payment_method_serializer.new(m, params: serializer_params).to_h },
                meta: { count: methods.size }
              }
            end
          end
        end
      end
    end
  end
end

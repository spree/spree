module Spree
  module Api
    module V3
      module Store
        module Carts
          class StoreCreditsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :require_authentication!
            before_action :find_cart!
            before_action :stringify_numeric_amount, only: :create

            request_params 'ApplyStoreCreditParams', action: :create do |body|
              body.attribute :amount, :decimal,
                example: '10.00',
                description: 'Defaults to as much as the cart can use. A JSON number is still read until 6.1, with a deprecation warning.'
            end

            # POST /api/v3/store/carts/:cart_id/store_credits
            def create
              with_order_lock do
                result = Spree.store_credit_apply_service.call(
                  order: @cart,
                  amount: money_param(:amount, @cart.currency)
                )

                if result.success?
                  sweep_unavailable_coupon_code!
                  render_cart
                else
                  render_service_error(result.error)
                end
              end
            end

            # DELETE /api/v3/store/carts/:cart_id/store_credits
            def destroy
              with_order_lock do
                result = Spree.store_credit_remove_service.call(order: @cart)

                if result.success?
                  sweep_unavailable_coupon_code!
                  render_cart
                else
                  render_service_error(result.error)
                end
              end
            end

            private

            # 5.6 storefronts sent a JSON number; read it through its text so no
            # float reaches the money math.
            def stringify_numeric_amount
              return unless params[:amount].is_a?(Numeric)

              Spree::Deprecation.warn('Sending the store credit amount as a JSON number is deprecated and will be refused in Spree 6.1. Send a decimal string such as "25.00".')
              params[:amount] = params[:amount].to_s
            end
          end
        end
      end
    end
  end
end

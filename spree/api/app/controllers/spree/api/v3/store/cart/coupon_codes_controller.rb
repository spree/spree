module Spree
  module Api
    module V3
      module Store
        module Cart
          class CouponCodesController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # POST  /api/v3/store/cart/coupon_codes
            # Apply a coupon code to the cart
            def create
              with_order_lock do
                @cart.coupon_code = permitted_params[:code]

                coupon_handler.apply

                if coupon_handler.successful?
                  render_cart(status: :created)
                else
                  render_errors(coupon_handler.error)
                end
              end
            end

            # DELETE  /api/v3/store/cart/coupon_codes/:id
            # Remove a coupon code from the cart
            # :id is the coupon code string (e.g., SAVE10)
            def destroy
              with_order_lock do
                coupon_handler.remove(params[:id])

                if coupon_handler.successful?
                  render_cart
                else
                  render_errors(coupon_handler.error)
                end
              end
            end

            private

            def coupon_handler
              @coupon_handler ||= Spree.coupon_handler.new(@cart)
            end

            def permitted_params
              params.permit(:code)
            end
          end
        end
      end
    end
  end
end

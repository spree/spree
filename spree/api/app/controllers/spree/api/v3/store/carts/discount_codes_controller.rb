module Spree
  module Api
    module V3
      module Store
        module Carts
          class DiscountCodesController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # POST  /api/v3/store/carts/:cart_id/discount_codes
            # Applies a discount code. A real-but-not-yet-eligible code is
            # accepted and persisted — recalculation activates the discount
            # the moment the cart qualifies (Shopify-parity). Unknown/expired
            # codes are rejected and never persisted.
            def create
              with_order_lock do
                @cart.coupon_code = permitted_params[:code]

                coupon_handler.apply

                if coupon_handler.successful? || pending_eligibility?
                  @cart.save!(validate: false) if @cart.changed?
                  @cart.reload
                  render_cart(status: :created)
                else
                  @cart.update_column(:coupon_code, nil) if @cart.read_attribute(:coupon_code).present?
                  render_errors(coupon_handler.error)
                end
              end
            end

            # DELETE  /api/v3/store/carts/:cart_id/discount_codes/:id
            # Remove a discount code from the cart
            # :id is the discount code string (e.g., SAVE10)
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
              @coupon_handler ||= Spree.coupon_handler.new(@cart, enable_gift_cards: false)
            end

            # A real code on a cart that doesn't qualify yet: the code is
            # kept and recalculation activates it later.
            def pending_eligibility?
              coupon_handler.status_code == :coupon_code_not_eligible
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

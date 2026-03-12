module Spree
  module Api
    module V3
      module Store
        module Checkout
          class StoreCreditsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :require_authentication!
            before_action :find_cart!

            # POST /api/v3/store/checkout/store_credits
            def create
              with_order_lock do
                result = Spree.checkout_add_store_credit_service.call(
                  order: @cart,
                  amount: params[:amount].try(:to_f)
                )

                if result.success?
                  render_cart
                else
                  render_service_error(result.error)
                end
              end
            end

            # DELETE /api/v3/store/checkout/store_credits
            def destroy
              with_order_lock do
                result = Spree.checkout_remove_store_credit_service.call(order: @cart)

                if result.success?
                  render_cart
                else
                  render_service_error(result.error)
                end
              end
            end
          end
        end
      end
    end
  end
end

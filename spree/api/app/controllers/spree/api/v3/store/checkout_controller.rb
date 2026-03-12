module Spree
  module Api
    module V3
      module Store
        class CheckoutController < Store::BaseController
          include Spree::Api::V3::CartResolvable
          include Spree::Api::V3::OrderLock

          before_action :find_cart!

          # PATCH  /api/v3/store/checkout
          # Update checkout info (email, addresses, special instructions).
          # Auto-advances to the next checkout step when possible.
          def update
            with_order_lock do
              result = Spree.checkout_update_service.call(
                order: @cart,
                params: checkout_params
              )

              if result.success?
                render_cart
              else
                render_service_error(result.error, code: ERROR_CODES[:validation_error])
              end
            end
          end

          # POST  /api/v3/store/checkout/complete
          # Complete the checkout — returns Order (not Cart)
          def complete
            with_order_lock do
              result = Spree.checkout_complete_service.call(order: @cart)

              if result.success?
                render_order
              else
                render_service_error(result.error, code: ERROR_CODES[:order_already_completed])
              end
            end
          end

          private

          def checkout_params
            params.permit(
              :email,
              :special_instructions,
              ship_address: address_params,
              bill_address: address_params,
              metadata: {}
            )
          end

          def address_params
            [
              :id, :firstname, :lastname, :address1, :address2,
              :city, :zipcode, :phone, :company,
              :country_iso, :state_abbr, :state_name, :quick_checkout
            ]
          end
        end
      end
    end
  end
end

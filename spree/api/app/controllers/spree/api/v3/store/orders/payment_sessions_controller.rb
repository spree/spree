module Spree
  module Api
    module V3
      module Store
        module Orders
          # Paying for a draft order the merchant raised — the cart payment
          # session endpoints, owned by the order instead.
          #
          # POST   /api/v3/store/orders/:order_id/payment_sessions
          # GET    /api/v3/store/orders/:order_id/payment_sessions/:id
          # PATCH  /api/v3/store/orders/:order_id/payment_sessions/:id
          # PATCH  /api/v3/store/orders/:order_id/payment_sessions/:id/complete
          class PaymentSessionsController < Store::BaseController
            include Spree::Api::V3::DraftOrderResolvable

            # A webhook can place the order before the buyer returns, so the
            # confirm replay still resolves a placed order.
            before_action { find_draft_order!(include_placed: action_name == 'complete') }

            include Spree::Api::V3::PaymentSessionActions

            protected

            def payment_session_owner
              @order
            end
          end
        end
      end
    end
  end
end

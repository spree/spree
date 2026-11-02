module Spree
  module Api
    module V3
      module Store
        module Carts
          # POST   /api/v3/store/carts/:cart_id/payment_sessions
          # GET    /api/v3/store/carts/:cart_id/payment_sessions/:id
          # PATCH  /api/v3/store/carts/:cart_id/payment_sessions/:id
          # PATCH  /api/v3/store/carts/:cart_id/payment_sessions/:id/complete
          class PaymentSessionsController < Store::BaseController
            include Spree::Api::V3::CartResolvable

            before_action :find_cart!

            include Spree::Api::V3::PaymentSessionActions

            protected

            def payment_session_owner
              @cart
            end

            # Payment confirmation races cart completion (a webhook can finish
            # checkout before the customer returns) — only the idempotent
            # confirm replay resolves completed carts. Creating or updating a
            # session on a finished checkout stays a 404.
            def find_cart!
              super(include_completed: action_name == 'complete')
            end
          end
        end
      end
    end
  end
end

module Spree
  module Api
    module V3
      module Admin
        # Handing money back is the `refunds` key's own authority, as it is on
        # the nested refunds endpoint: a role that settles returns, claims and
        # exchanges, or cancels orders, under `orders` does not thereby decide
        # to refund them. The store back office's gate only — a seller refunds
        # their own orders under the seller panel's `orders` key.
        module RefundAuthorization
          extend ActiveSupport::Concern

          REFUND_PERMISSION = 'write_refunds'.freeze

          private

          def require_refund_permission!
            return if holds_permission?(REFUND_PERMISSION)

            render_missing_permission(REFUND_PERMISSION)
          end
        end
      end
    end
  end
end

module Spree
  module Api
    module V3
      module Store
        module Carts
          # Replaces a guest cart's token. A cart token is a bearer credential:
          # whoever built the cart — an AI shopping agent, or anyone who sent
          # the buyer a link to it — still holds it after the buyer takes the
          # cart over, and with it the buyer's address and the order the cart
          # becomes. The storefront calls this when it adopts a cart from a
          # link, so the link stops working and only the buyer's browser keeps
          # the cart.
          class TokensController < Store::BaseController
            include Spree::Api::V3::CartResolvable

            before_action :find_cart!
            before_action :require_cart_token!

            # PATCH /api/v3/store/carts/:cart_id/token
            def update
              @cart.regenerate_token
              render_cart
            end

            private

            # Only the holder of the current token may replace it — a signed-in
            # owner reaching the cart by session has no link to revoke.
            def require_cart_token!
              valid = cart_token.present? && ActiveSupport::SecurityUtils.secure_compare(cart_token, @cart.token.to_s)

              raise Spree::Storefront::AccessDenied unless valid
            end
          end
        end
      end
    end
  end
end

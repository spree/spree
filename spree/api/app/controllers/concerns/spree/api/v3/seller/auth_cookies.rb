module Spree
  module Api
    module V3
      module Seller
        # Cookie-based delivery for seller refresh tokens.
        #
        # Both the name and the path differ from the admin cookie, and both
        # matter: a shared name would let one browser's admin session be
        # redeemed on the seller panel, and the path is what stops each
        # surface's cookie being sent to the other's endpoints. Together with
        # the audience stamped on the token itself, a session belongs to
        # exactly one surface.
        #
        # The CSRF reasoning is the admin concern's, unchanged: SameSite plus
        # the Spree::AllowedOrigin allowlist. A seller dashboard served from an
        # origin outside that allowlist would need its own answer.
        module AuthCookies
          extend ActiveSupport::Concern

          # ActionController::API drops Cookies — re-include it on the auth
          # controller only; the rest of the branch stays stateless.
          included do
            include ActionController::Cookies
          end

          REFRESH_COOKIE_NAME = :spree_seller_refresh_token
          COOKIE_PATH = '/api/v3/seller/auth'.freeze

          private

          def set_refresh_cookie(refresh_token)
            cookies.signed[REFRESH_COOKIE_NAME] = base_cookie_attributes.merge(
              value: refresh_token.token,
              expires: refresh_token.expires_at,
              path: COOKIE_PATH,
              httponly: true
            )
          end

          def clear_refresh_cookie
            cookies.delete(REFRESH_COOKIE_NAME, path: COOKIE_PATH)
          end

          def refresh_token_from_cookie
            cookies.signed[REFRESH_COOKIE_NAME].presence
          end

          # Keyed off the request scheme, not the Rails env: Rails silently
          # refuses to write a Secure cookie on a non-SSL request, so an app
          # served over plain http would never receive one at all.
          def base_cookie_attributes
            if request.ssl?
              { secure: true, same_site: :none }
            else
              { secure: false, same_site: :lax }
            end
          end
        end
      end
    end
  end
end

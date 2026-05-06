module Spree
  module Api
    module V3
      module Admin
        # Cookie-based delivery for admin refresh tokens.
        #
        # Refresh token: HttpOnly signed cookie at /api/v3/admin/auth — invisible to JS,
        #                tamper-evident via Rails' cookie signing.
        #
        # CSRF protection:
        #   We deliberately do NOT use a CSRF token here. The threat model is fully
        #   covered by the combination of:
        #     - SameSite=Lax (dev) / SameSite=None; Secure (prod) on the refresh cookie
        #     - Spree::AllowedOrigin allowlist enforced via Rack::Cors with credentials: true
        #     - CORS preflight blocking cross-origin requests from non-allowlisted Origins
        #   A double-submit CSRF token would only add value if the AllowedOrigin allowlist
        #   were misconfigured or if an XSS happened on a different allowlisted origin —
        #   both scenarios where a defender's deeper problem outweighs CSRF mitigation.
        #   See docs/plans/5.5-admin-auth-cookie-refresh.md for the full reasoning.
        module AuthCookies
          extend ActiveSupport::Concern

          # ActionController::API drops Cookies — re-include it on the auth controller only.
          # Rest of the admin API stays cookie-free and stateless.
          included do
            include ActionController::Cookies
          end

          REFRESH_COOKIE_NAME = :spree_admin_refresh_token
          COOKIE_PATH = '/api/v3/admin/auth'.freeze

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

          def base_cookie_attributes
            if Rails.env.production?
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

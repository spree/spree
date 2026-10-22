module Spree
  module Api
    module V3
      module Oauth
        # Doorkeeper's token endpoints — the code exchange, refresh,
        # revocation and introspection — behind the throttle the rest of the
        # API has.
        #
        # Doorkeeper's controllers sit outside the API's base controller, so
        # none of its limits applied to the one request that turns a code
        # into a credential. Bucketed by address, because nothing on these
        # requests has been authenticated yet.
        class TokensController < ::Doorkeeper::TokensController
          rate_limit to: Spree::Api::Config[:rate_limit_per_key],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     scope: 'oauth_tokens',
                     by: -> { request.remote_ip },
                     with: -> { render_rate_limited }

          private

          # In the token endpoint's own error shape (RFC 6749 §5.2), so a
          # client reads one format from it.
          def render_rate_limited
            response.headers['Retry-After'] = Spree::Api::Config[:rate_limit_window].to_s
            render json: { error: 'rate_limit_exceeded', error_description: 'Too many requests. Please retry later.' },
                   status: :too_many_requests
          end
        end
      end
    end
  end
end

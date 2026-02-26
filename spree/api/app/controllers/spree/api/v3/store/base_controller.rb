module Spree
  module Api
    module V3
      module Store
        class BaseController < Spree::Api::V3::BaseController
          RATE_LIMIT_RESPONSE = -> {
            body = { error: { code: 'rate_limit_exceeded', message: 'Too many requests. Please retry later.' } }
            [429, { 'Content-Type' => 'application/json', 'Retry-After' => '60' }, [body.to_json]]
          }

          # Global rate limit per publishable API key
          rate_limit to: Spree::Api::Config[:rate_limit_per_key], within: 1.minute,
                     store: Rails.cache,
                     by: -> { request.headers['X-Spree-Api-Key'] || request.remote_ip },
                     with: RATE_LIMIT_RESPONSE

          # Require publishable API key for all Store API requests
          before_action :authenticate_api_key!
        end
      end
    end
  end
end

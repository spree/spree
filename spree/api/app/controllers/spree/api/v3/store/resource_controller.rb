module Spree
  module Api
    module V3
      module Store
        class ResourceController < Spree::Api::V3::ResourceController
          include Spree::Api::V3::RateLimitHeaders

          RATE_LIMIT_RESPONSE = Store::BaseController::RATE_LIMIT_RESPONSE

          # Global rate limit per publishable API key
          rate_limit to: Spree::Api::Config[:rate_limit_per_key], within: Spree::Api::Config[:rate_limit_window].seconds,
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

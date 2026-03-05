module Spree
  module Api
    module V3
      module Admin
        class ResourceController < Spree::Api::V3::ResourceController
          include Spree::Api::V3::RateLimitHeaders

          RATE_LIMIT_RESPONSE = Admin::BaseController::RATE_LIMIT_RESPONSE

          # Global rate limit per secret API key
          rate_limit to: Spree::Api::Config[:rate_limit_per_key], within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     by: -> { request.headers['X-Spree-Api-Key'] || request.remote_ip },
                     with: RATE_LIMIT_RESPONSE

          # Require secret API key for all Admin API requests
          before_action :authenticate_secret_key!

          protected

          # Override JWT audience to require admin tokens
          def expected_audience
            JWT_AUDIENCE_ADMIN
          end
        end
      end
    end
  end
end

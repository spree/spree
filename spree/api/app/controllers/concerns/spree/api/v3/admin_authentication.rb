module Spree
  module Api
    module V3
      module AdminAuthentication
        extend ActiveSupport::Concern

        included do
          before_action :authenticate_admin!
          after_action :set_no_store_cache
        end

        protected

        # Override JWT audience to require admin tokens
        def expected_audience
          Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
        end

        # Authenticates admin requests via secret API key OR JWT token.
        # Secret keys are checked first (server-to-server integrations),
        # then JWT tokens (admin SPA sessions).
        def authenticate_admin!
          # Try secret API key first
          @current_api_key = Spree::ApiKey.find_by_secret_token(extract_api_key)
          @current_api_key = nil if @current_api_key && @current_api_key.store_id != current_store.id

          if @current_api_key
            touch_api_key_if_needed(@current_api_key)
            return true
          end

          # Fall back to JWT authentication
          require_authentication!
        end

        private

        def set_no_store_cache
          response.headers['Cache-Control'] = 'private, no-store'
        end
      end
    end
  end
end

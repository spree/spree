module Spree
  module Api
    module V3
      module AdminAuthentication
        extend ActiveSupport::Concern

        included do
          after_action :set_no_store_cache
        end

        protected

        # Override JWT audience to require admin tokens
        def expected_audience
          Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
        end

        # API-key-only requests bypass CanCanCan: the ScopedAuthorization
        # concern is the authoritative gate (read_/write_ scopes per resource).
        # JWT admin users keep CanCanCan abilities; if both credentials are
        # present, the JWT user wins for permission resolution.
        def current_ability
          return super if current_user
          return super unless @current_api_key

          @current_ability ||= Spree::ApiKeyAbility.new(ability_options)
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

          # Fall back to JWT authentication, then bind the admin to the store
          # they hold a role on (the token itself is store-agnostic).
          return false unless require_authentication!

          require_store_membership!
        end

        private

        # Rejects an authenticated JWT admin who has no role on +current_store+.
        # API-key principals are already store-bound and skip this check.
        def require_store_membership!
          return true if current_user_member_of_store?

          render_error(
            code: ErrorHandler::ERROR_CODES[:access_denied],
            message: 'You do not have access to this store.',
            status: :forbidden
          )
          false
        end

        def current_user_member_of_store?
          return false unless current_user.respond_to?(:role_users)

          current_user.role_users.exists?(resource: current_store)
        end

        def set_no_store_cache
          response.headers['Cache-Control'] = 'private, no-store'
        end
      end
    end
  end
end

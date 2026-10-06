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

        # A key-authenticated write records the key: it is the thing that gets
        # named, scoped and revoked, so it is what an order's `canceler` or a
        # receipt's `received_by` should point at. A JWT request records the
        # admin. When both credentials are present the JWT user wins here too,
        # matching how permissions resolve below.
        #
        # @return [Object, nil]
        def current_actor
          try_spree_current_user || @current_api_key
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
          # Try secret API key first — the key selects the request's store
          # (Admin::StoreContext), so there is no store check to make here.
          @current_api_key = secret_api_key

          if @current_api_key
            touch_api_key_if_needed(@current_api_key)
            return true
          end

          # Then an OAuth token, which carries both the admin who granted it
          # and the store its client was registered for, so neither a JWT's
          # store-membership check nor a key's store selection applies.
          return true if authenticate_admin_oauth_token

          # Fall back to JWT authentication, then bind the admin to the store
          # they hold a role on (the token itself is store-agnostic).
          return false unless require_authentication!

          require_store_membership!
        end

        private

        # An OAuth bearer token, accepted only when it was issued for this
        # API. A token names the resources it may be used against (RFC 8707),
        # and a client asking for one endpoint must not receive a credential
        # good across the rest — so a token naming only the MCP endpoint is
        # refused here, and the MCP controller refuses one naming only this.
        #
        # @return [Boolean] true when the request is now authenticated
        def authenticate_admin_oauth_token
          token = admin_oauth_token
          return false if token.nil?

          owner = token.resource_owner
          return false unless owner.is_a?(Spree.admin_user_class)

          @current_api_key = nil
          @current_user = owner
          true
        end

        # @return [Spree::OauthAccessToken, nil]
        def admin_oauth_token
          return @admin_oauth_token if defined?(@admin_oauth_token)

          @admin_oauth_token = begin
            token = Spree::OauthAccessToken.by_token(oauth_bearer_value)
            token if token&.accessible? && admin_audience_matches?(token)
          end
        end

        # Split rather than matched: a regex with `\s+(.+)` backtracks on a
        # header of many spaces, and this one is attacker-supplied on an
        # unauthenticated request.
        #
        # @return [String, nil]
        def oauth_bearer_value
          scheme, value = request.headers['Authorization'].to_s.split(' ', 2)
          return unless scheme&.casecmp?('Bearer')

          value.to_s.strip.presence
        end

        # Compared by path, because the origin a client was given varies with
        # how the installation is reached — a tunnel, a proxy, a custom
        # domain — while the path it names does not. An unbound token is
        # refused rather than trusted.
        def admin_audience_matches?(token)
          expected = Spree::Api::Oauth.resources[:admin]
          return false if expected.blank?

          token.resource.to_s.split.any? do |indicator|
            URI.parse(indicator).path == expected
          rescue URI::InvalidURIError
            false
          end
        end

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

        # Membership is holding a role the store itself owns, mirroring
        # Spree::Ability#staff_roles. A role belonging to another resource — a
        # marketplace seller, say — is that panel's business and never admits
        # its holder here.
        def current_user_member_of_store?
          return false unless current_user.respond_to?(:spree_roles)

          current_user.spree_roles.for_resource(current_store).exists?
        end

        def set_no_store_cache
          response.headers['Cache-Control'] = 'private, no-store'
        end
      end
    end
  end
end

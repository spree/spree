module Spree
  module Api
    # OAuth 2.1 authorization server for the Spree API.
    #
    # Spree is the authorization server here, not a client of one: a
    # self-hosted store has no external identity provider to delegate to, and
    # requiring one would exclude the installations this exists for. This is
    # the opposite direction from SSO login, which makes Spree an OIDC client
    # so staff can sign in through a provider; the two share a spec family and
    # almost no code.
    #
    # The first consumer is the Admin MCP server, whose consumer clients
    # (hosted connectors) accept no other credential. A marketplace app or a
    # merchant-approved integration is the same flow with a different client,
    # which is why this lives in `spree_api` rather than in any one gem that
    # happens to need it.
    module Oauth
      # Protected resources, each registered by the surface that owns it.
      #
      # A resource identifier must equal the URL the client was pointed at,
      # path included, or a consumer client refuses the connection — so the
      # owning surface supplies it rather than this module guessing.
      #
      #   Spree.api.oauth.register_resource(:mcp) do |store|
      #     "#{store.formatted_url}/api/v3/admin/mcp"
      #   end
      mattr_accessor :resources, default: {}

      class << self
        # @param key [Symbol]
        # @yieldparam store [Spree::Store]
        # @yieldreturn [String] the resource identifier for that store
        def register_resource(key, &identifier)
          resources[key.to_sym] = identifier
        end

        # @param store [Spree::Store]
        # @return [Array<String>] every resource identifier this installation
        #   serves for the store
        def resource_identifiers(store)
          resources.values.map { |identifier| identifier.call(store) }
        end

        # @param key [Symbol]
        # @param store [Spree::Store]
        # @return [String, nil]
        def resource_identifier(key, store)
          resources[key.to_sym]&.call(store)
        end

        def configure!
          ::Doorkeeper.configure do
            orm :active_record

            application_class 'Spree::OauthApplication'
            access_grant_class 'Spree::OauthAccessGrant'
            access_token_class 'Spree::OauthAccessToken'

            # The consent controller signs the user in before Doorkeeper runs,
            # so the authorization server never needs to know how
            # authentication works.
            resource_owner_authenticator { send(:current_oauth_resource_owner) }

            # An admin user today, a customer when a storefront client needs
            # one — recorded polymorphically so either can own a grant.
            use_polymorphic_resource_owner

            # Authorization code only. A password grant asks a client to
            # handle someone's password, and client credentials identify no
            # person, so neither belongs on a surface whose authority is a
            # user's own permissions.
            grant_flows %w[authorization_code]

            # Mandatory, not merely supported: these are public clients, and
            # without PKCE an intercepted code is enough to obtain a token.
            force_pkce
            # S256 only — `plain` is in the gem's defaults and protects
            # nothing against an intercepted code.
            pkce_code_challenge_methods %w[S256]

            # RFC 8707. Registering the validator is what binds an audience
            # into the token; left nil, the `resource` parameter is ignored
            # and a token minted for another service would be accepted.
            resource_indicator_validator(lambda do |requested, _client|
              allowed = Spree::Store.all.flat_map do |store|
                Spree::Api::Oauth.resource_identifiers(store)
              end
              requested.any? && requested.all? { |indicator| allowed.include?(indicator) }
            end)

            # Spree's own permission catalog is the scope vocabulary, so a
            # grant carries the same keys an API key would and the tool
            # registry needs no translation. Resolved at configuration time
            # from the catalog rather than hardcoded, so a scope an extension
            # registers is grantable without touching this.
            optional_scopes(*Spree.permissions.grantable_keys(
              Spree::PermissionConfiguration::STAFF_AUDIENCE
            ))

            use_refresh_token
            # One live token per authorization, so re-consenting does not
            # leave the previous one usable.
            revoke_previous_authorization_code_token
            hash_token_secrets fallback: :plain
            access_token_expires_in 2.hours
            # Refresh rotation with replay detection comes from the
            # `previous_refresh_token` column the migration adds — Doorkeeper
            # enables it by the column's presence, not by a setting.

            api_only
            handle_auth_errors :raise
            # Never from a query parameter: the spec forbids it, and a URL
            # reaches logs and proxies.
            access_token_methods :from_bearer_authorization
          end
        end
      end
    end
  end
end

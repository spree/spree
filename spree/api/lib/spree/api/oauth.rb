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
      # Protected resources, each registered by the surface that owns it as a
      # path relative to this application's own origin.
      #
      #   Spree::Api::Oauth.register_resource(:mcp, '/api/v3/admin/mcp')
      #
      # A path rather than a full URL because the identifier must equal the
      # URL the client was actually pointed at: the origin comes from the
      # request where there is one, and from the application's configured
      # URL options otherwise. A store's own `url` column is deliberately not
      # consulted — it describes the storefront, which is frequently neither
      # the host nor the scheme the Admin API answers on.
      # The aliases, offered alongside the individual keys.
      #
      # A grant that enumerates every key is frozen at the moment it was
      # given: ship a feature with new permissions and every existing
      # connection silently lacks them, with nothing to tell the merchant why
      # its agent stopped seeing the new tools. `write_all` keeps meaning
      # "everything" as the catalog grows, which is what a merchant who
      # ticked "Full access" believed they were agreeing to.
      ALIAS_SCOPES = %w[read_all write_all].freeze

      mattr_accessor :resources, default: {}

      class << self
        # @param key [Symbol]
        # @param path [String] absolute path this resource answers on
        def register_resource(key, path)
          resources[key.to_sym] = path
        end

        # @param origin [String, nil] scheme and host the client used
        # @return [Array<String>] every resource identifier this installation
        #   serves
        def resource_identifiers(origin = nil)
          base = origin.presence || application_origin
          resources.values.map { |path| "#{base}#{path}" }
        end

        # @param key [Symbol]
        # @param origin [String, nil] scheme and host the client used
        # @return [String, nil]
        def resource_identifier(key, origin = nil)
          path = resources[key.to_sym]
          return if path.nil?

          "#{origin.presence || application_origin}#{path}"
        end

        # Where this application answers, from the URL options a deployment
        # already has to set for mailer links to work.
        #
        # @return [String]
        def application_origin
          options = Rails.application.routes.default_url_options
          host = options[:host]
          return '' if host.blank?

          origin = "#{options[:protocol].presence || 'https'}://#{host}"
          options[:port].present? ? "#{origin}:#{options[:port]}" : origin
        end

        # The grantable scope list, re-read after host and extension
        # initializers have run.
        #
        # `optional_scopes` builds its value eagerly, and an extension
        # registers its scopes from a config initializer — which runs after
        # {.configure!}, because a host's own `doorkeeper.rb` has to be able
        # to win. Without this second pass the vocabulary would be whatever
        # core shipped, and an extension's keys could never be granted.
        def refresh_scopes!
          ::Doorkeeper.config.instance_variable_set(
            :@optional_scopes,
            ::Doorkeeper::OAuth::Scopes.from_array(staff_scope_keys)
          )
        end

        # @return [Array<String>]
        def staff_scope_keys
          ALIAS_SCOPES + Spree.permissions.grantable_keys(Spree::PermissionConfiguration::STAFF_AUDIENCE)
        end

        # Whether every requested audience names a resource this application
        # actually serves.
        #
        # Compared by path rather than by full URL: the origin a client used
        # is whatever it was pointed at, and a deployment behind a proxy or
        # reachable at several hostnames would otherwise refuse its own
        # tokens.
        #
        # @param requested [Array<String>] the `resource` values asked for
        # @return [Boolean]
        def indicators_valid?(requested, _client = nil)
          return false if requested.blank?

          paths = resources.values
          requested.all? do |indicator|
            path = URI.parse(indicator.to_s).path
            paths.include?(path)
          rescue URI::InvalidURIError
            false
          end
        end

        def configure!
          ::Doorkeeper.configure do
            orm :active_record

            application_class 'Spree::OauthApplication'
            access_grant_class 'Spree::OauthAccessGrant'
            access_token_class 'Spree::OauthAccessToken'

            # Consent is Spree's own, at
            # `Spree::Api::V3::Admin::Oauth::AuthorizationsController`, and
            # Doorkeeper's authorization controllers are not mounted — so
            # this is only reached if a host app mounts them. Failing loudly
            # beats a NoMethodError inside a before_action, which
            # `handle_auth_errors :raise` would turn into a 500 on an
            # authorization endpoint.
            resource_owner_authenticator do
              raise "Doorkeeper's own consent screens are not mounted in Spree. " \
                    'Consent is served by the Admin API at /api/v3/admin/oauth/authorize.'
            end

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
              Spree::Api::Oauth.indicators_valid?(requested)
            end)

            # Spree's own permission catalog is the scope vocabulary, so a
            # grant carries the same keys an API key would and the tool
            # registry needs no translation. Seeded here and re-read in
            # `refresh_scopes!` once extensions have registered theirs.
            optional_scopes(*Spree::Api::Oauth.staff_scope_keys)

            use_refresh_token
            # One live token per authorization, so re-consenting does not
            # leave the previous one usable.
            revoke_previous_authorization_code_token
            # No `fallback: :plain`: every token this server writes is
            # hashed, so a plaintext lookup could never match and keeping
            # the path alive only invites a future migration to rely on it.
            hash_token_secrets
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

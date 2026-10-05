module Spree
  module Api
    module V3
      module Admin
        # The MCP endpoint: `POST /api/v3/admin/mcp`.
        #
        # An ordinary admin API controller rather than the gem's Rack
        # transport, which takes one pre-built server for every request and so
        # cannot carry a per-request principal. Here the key authenticates
        # through the concern every other admin endpoint uses, selects the
        # store the same way, and gets a server built for it alone.
        #
        # Stateless: one JSON-RPC message per request, one JSON response, no
        # session and no server-to-client stream, so any Puma worker answers
        # any request.
        #
        # See docs/plans/6.0-mcp-server.md.
        class McpController < Spree::Api::V3::Admin::BaseController
          # The scope gate is per tool, not per request: a call carries the
          # tool it wants inside the JSON-RPC body, and every tool already
          # declares the permission it needs. Checking one scope for the whole
          # endpoint would mean either refusing a key that may legitimately
          # read, or waving through a write the key cannot make.
          skip_scope_check!

          # Prepended so it answers before the inherited authentication does.
          # The generic "Authentication required" is useless to an agent: this
          # text is what both the model and the person actually read when a
          # client is misconfigured, so it has to say which credential to
          # send and where it comes from.
          #
          # A JWT is still refused. It belongs to a signed-in admin in a
          # browser, and a dashboard session is not what should drive an
          # agent — the dashboard assistant is that path, over the same
          # registry.
          prepend_before_action :require_agent_credential!

          def create
            render json: server.handle_json(request.body.read), content_type: 'application/json'
          end

          protected

          # An OAuth token is a third credential the inherited concern knows
          # nothing about, so it is resolved here. The grant already bound
          # the token to a real admin user and this request's audience check
          # confirmed it was issued for this store's endpoint, which is the
          # same assurance `require_store_membership!` gives a JWT.
          def authenticate_admin!
            return super if oauth_token.blank?

            owner = oauth_resource_owner
            return false if owner.nil?

            @current_api_key = nil
            @current_user = owner
            true
          end

          # The key in either of the two forms clients offer. Several MCP
          # clients have a bearer-token field and no way to set a custom
          # header, so a secret key is accepted there too. The `sk_` prefix
          # keeps it unambiguous against the JWTs the Admin API also accepts
          # in `Authorization`, and a JWT presented here resolves to no key
          # and is refused below.
          def extract_api_key
            super.presence || bearer_secret_key
          end

          private

          # Split rather than matched: a regex with `\s+(.+)` backtracks on a
          # header of many spaces, and this one is attacker-supplied on an
          # unauthenticated request.
          def bearer_secret_key
            value = bearer_value
            value if value&.start_with?(Spree::ApiKey::PREFIXES['secret'])
          end

          # Split rather than matched, for the same reason: this header is
          # attacker-supplied on an unauthenticated request.
          def bearer_value
            scheme, value = request.headers['Authorization'].to_s.split(' ', 2)
            return unless scheme&.casecmp?('Bearer')

            value.to_s.strip.presence
          end

          def server
            Spree::Mcp::Server.for(agent_context)
          end

          # Either credential resolves into the same context, so the tool
          # catalog never learns which one a request used. A key's authority
          # is its scopes; a token's is the admin user's own permissions,
          # resolved fresh here rather than frozen when the token was issued.
          def agent_context
            if oauth_token.present?
              Spree::AgentTools::Context.new(
                store: current_store,
                user: oauth_resource_owner,
                granted_scopes: oauth_token.scopes.to_a
              )
            else
              Spree::AgentTools::Context.new(store: current_store, api_key: current_api_key)
            end
          end

          # RFC 6750: the challenge names where to discover the authorization
          # server, which is how a consumer client starts its own sign-in.
          #
          # The metadata URL is derived from the resource identifier rather
          # than from route helpers, so both carry the same scheme and host.
          # A client compares them, and http-versus-https is enough for it to
          # decide the document describes a different resource and stop.
          #
          # No `scope`: it is a SHOULD, and listing every grantable key makes
          # a header several kilobytes long. A client reads the real list from
          # the metadata document.
          def oauth_challenge
            resource = Spree::Api::Oauth.resource_identifier(:mcp, current_store)
            base = resource.sub(%r{/api/v3/admin/mcp\z}, '')

            format(
              'Bearer realm="%<realm>s", resource_metadata="%<metadata>s"',
              realm: resource,
              metadata: "#{base}/api/v3/oauth/protected-resource/mcp"
            )
          end

          # A token issued for another resource must not work here, whatever
          # its scopes say. Doorkeeper binds the audience at issue; this is
          # the check that it matches.
          # The hook ScopedAuthorization reads, so a grant narrows this
          # request's authority through the same path every admin endpoint
          # uses rather than only here.
          def current_oauth_token
            oauth_token
          end

          # A token selects its own store, the way a secret key does.
          #
          # An MCP client sends a URL and a bearer token and nothing else — it
          # has no way to set the store header the Admin API otherwise uses —
          # so without this a token granted for any store but the default one
          # would be measured against the default store's resource identifier
          # and always fail its audience check.
          def resolve_admin_store
            application_store || super
          end

          def application_store
            return if bearer_value.blank?
            return if bearer_value.start_with?(Spree::ApiKey::PREFIXES['secret'])

            Spree::OauthAccessToken.by_token(bearer_value)&.application&.store
          end

          def oauth_token
            return @oauth_token if defined?(@oauth_token)

            @oauth_token = begin
              raw = bearer_value
              if raw.blank? || raw.start_with?(Spree::ApiKey::PREFIXES['secret'])
                nil
              else
                token = Spree::OauthAccessToken.by_token(raw)
                token if token&.accessible? && audience_matches?(token)
              end
            end
          end

          # Deliberately stricter than Doorkeeper's own
          # `resource_indicators_match?`, which treats "neither side names a
          # resource" as a match. Here an unbound token must be refused: the
          # whole point of the audience is that a token minted for another
          # resource cannot be replayed against this one, and a token with no
          # audience cannot be shown to have been issued for this endpoint.
          def audience_matches?(token)
            expected = Spree::Api::Oauth.resource_identifier(:mcp, current_store)
            return false if expected.blank?

            token.resource.to_s.split.include?(expected)
          end

          def oauth_resource_owner
            owner = oauth_token.resource_owner
            owner if owner.is_a?(Spree.admin_user_class)
          end

          # The error text is what both the model and the person read, so it
          # says which header to set and where the key comes from rather than
          # only that something was missing.
          # Two ways in: a secret key a developer configured, or an OAuth
          # token a merchant approved. A 401 carries the OAuth challenge, so
          # a consumer client that arrives with nothing discovers how to sign
          # in rather than simply failing.
          def require_agent_credential!
            return if secret_api_key.present? || oauth_token.present?

            response.headers['WWW-Authenticate'] = oauth_challenge

            render json: {
              jsonrpc: '2.0',
              id: nil,
              error: {
                code: -32_001,
                message: 'Authentication is required. Either sign in through this store (your ' \
                         'client will offer that when it reads the challenge on this response), ' \
                         'or send a secret API key as `X-Spree-API-Key: sk_…` or ' \
                         '`Authorization: Bearer sk_…` — mint one in the dashboard under ' \
                         'Settings → API keys, granting only the scopes this agent needs.'
              }
            }, status: :unauthorized
          end
        end
      end
    end
  end
end

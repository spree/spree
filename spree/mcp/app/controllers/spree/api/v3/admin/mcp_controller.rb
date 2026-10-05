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
          # declares the permission it needs. Checking one grant's scopes for
          # the whole endpoint would mean either refusing a read it covers or
          # waving through a write it does not.
          skip_scope_check!

          # Prepended so it answers before the inherited authentication does.
          # The generic "Authentication required" is useless to an agent: this
          # text is what both the model and the person actually read when a
          # client is misconfigured.
          prepend_before_action :require_oauth_token!

          def create
            render json: server.handle_json(request.body.read), content_type: 'application/json'
          end

          protected

          # The only credential this endpoint takes. An agent acts for a
          # person, so it carries that person's grant: the token names who
          # approved it and what they allowed, both of which a standing key
          # cannot express. A secret key authenticates the rest of the Admin
          # API and the `spree api` CLI; it is deliberately not accepted
          # here.
          #
          # The grant already bound the token to a real admin user and the
          # audience check confirmed it was issued for this endpoint, which
          # is the assurance `require_store_membership!` gives a JWT.
          def authenticate_admin!
            owner = oauth_resource_owner
            # A `before_action` halts on a render, not on a falsy return, so
            # refusing has to render. The grant's owner is an admin in every
            # path that exists today; a customer-owned token would otherwise
            # reach the action and die as a confusing 422 further in.
            return refuse_unauthenticated if owner.nil?

            @current_api_key = nil
            @current_user = owner
            true
          end

          private

          # Split rather than matched: a regex with `\s+(.+)` backtracks on a
          # header of many spaces, and this one is attacker-supplied on an
          # unauthenticated request.
          def bearer_value
            scheme, value = request.headers['Authorization'].to_s.split(' ', 2)
            return unless scheme&.casecmp?('Bearer')

            value.to_s.strip.presence
          end

          def server
            Spree::Mcp::Server.for(agent_context)
          end

          # The caller's authority is the admin user's own permissions,
          # narrowed by what they consented to — resolved on every request
          # rather than frozen when the token was issued, so narrowing a role
          # takes effect immediately.
          def agent_context
            Spree::AgentTools::Context.new(
              store: current_store,
              user: oauth_resource_owner,
              granted_scopes: current_oauth_token.scopes.to_a
            )
          end

          # RFC 6750: the challenge names where to discover the authorization
          # server, which is how a consumer client starts its own sign-in.
          #
          # Both URLs are built from the origin this request arrived on, so
          # they match what the client used and each other. A client compares
          # them, and a different scheme or host is enough for it to decide
          # the document describes another resource and stop.
          #
          # No `scope`: it is a SHOULD, and listing every grantable key makes
          # a header several kilobytes long. A client reads the real list from
          # the metadata document.
          def oauth_challenge
            format(
              'Bearer realm="%<realm>s", resource_metadata="%<metadata>s"',
              realm: Spree::Api::Oauth.resource_identifier(:mcp, request.base_url),
              metadata: "#{request.base_url}/api/v3/oauth/protected-resource/mcp"
            )
          end

          # A token issued for another resource must not work here, whatever
          # its scopes say. Doorkeeper binds the audience at issue; this is
          # the check that it matches.
          # A token selects its own store, the way a secret key does.
          #
          # An MCP client sends a URL and a bearer token and nothing else — it
          # has no way to set the store header the Admin API otherwise uses —
          # so without this a token granted for any store but the default one
          # would be measured against the default store's resource identifier
          # and always fail its audience check.
          def resolve_admin_store
            bearer_access_token&.application&.store || super
          end

          # The token the bearer header names, before any check of whether it
          # may be used here. Resolving the store needs it, and the audience
          # check needs the store, so the lookup has to come first — and it is
          # memoized because three callers want the same row.
          def bearer_access_token
            return @bearer_access_token if defined?(@bearer_access_token)

            raw = bearer_value
            @bearer_access_token = raw.present? ? Spree::OauthAccessToken.by_token(raw) : nil
          end

          # The token this request may actually act on: live, and issued for
          # this endpoint. Named for the hook ScopedAuthorization reads, so a
          # grant narrows authority through the same path every admin
          # endpoint uses rather than only here.
          def current_oauth_token
            return @current_oauth_token if defined?(@current_oauth_token)

            token = bearer_access_token
            @current_oauth_token = token if token&.accessible? && audience_matches?(token)
          end

          # Deliberately stricter than Doorkeeper's own
          # `resource_indicators_match?`, which treats "neither side names a
          # resource" as a match. Here an unbound token must be refused: the
          # whole point of the audience is that a token minted for another
          # resource cannot be replayed against this one, and a token with no
          # audience cannot be shown to have been issued for this endpoint.
          # Compared by path: a token minted through one hostname must keep
          # working through another the same deployment answers on, while a
          # token naming a different resource entirely is still refused.
          def audience_matches?(token)
            expected = Spree::Api::Oauth.resources[:mcp]
            return false if expected.blank?

            token.resource.to_s.split.any? do |indicator|
              URI.parse(indicator).path == expected
            rescue URI::InvalidURIError
              false
            end
          end

          def oauth_resource_owner
            owner = current_oauth_token.resource_owner
            owner if owner.is_a?(Spree.admin_user_class)
          end

          # The error text is what both the model and the person read, so it
          # says which header to set and where the key comes from rather than
          # only that something was missing.
          # Two ways in: a secret key a developer configured, or an OAuth
          # token a merchant approved. A 401 carries the OAuth challenge, so
          # a consumer client that arrives with nothing discovers how to sign
          # in rather than simply failing.
          # A 401 carrying the discovery header, which is how a client that
          # arrived with nothing learns where to sign in rather than simply
          # failing.
          def require_oauth_token!
            return if current_oauth_token.present?

            refuse_unauthenticated
          end

          def refuse_unauthenticated
            response.headers['WWW-Authenticate'] = oauth_challenge

            render json: {
              jsonrpc: '2.0',
              id: nil,
              error: {
                code: -32_001,
                message: 'Sign in to this store to continue. Your client will offer that when ' \
                         'it reads the challenge on this response. A Spree API key is not ' \
                         'accepted here — an agent acts for a person, so it carries that ' \
                         "person's own permissions. Use the `spree api` CLI for scripted " \
                         'access that cannot sign in.'
              }
            }, status: :unauthorized
          end
        end
      end
    end
  end
end

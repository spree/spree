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
          # client is misconfigured, so it has to say which header to set and
          # where a key comes from.
          #
          # It also makes this a machine-only surface. A JWT belongs to a
          # signed-in admin, and a browser session is not what should drive an
          # agent — the dashboard assistant is that path, over the same
          # registry.
          prepend_before_action :require_secret_key!

          def create
            render json: server.handle_json(request.body.read), content_type: 'application/json'
          end

          protected

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
            scheme, token = request.headers['Authorization'].to_s.split(' ', 2)
            return unless scheme&.casecmp?('Bearer')

            token = token.to_s.strip
            token if token.start_with?(Spree::ApiKey::PREFIXES['secret'])
          end

          def server
            Spree::Mcp::Server.for(agent_context)
          end

          def agent_context
            Spree::AgentTools::Context.new(store: current_store, api_key: current_api_key)
          end

          # The error text is what both the model and the person read, so it
          # says which header to set and where the key comes from rather than
          # only that something was missing.
          def require_secret_key!
            return if secret_api_key.present?

            render json: {
              jsonrpc: '2.0',
              id: nil,
              error: {
                code: -32_001,
                message: 'A Spree secret API key is required. Send it as `X-Spree-API-Key: sk_…` ' \
                         'or `Authorization: Bearer sk_…`. Mint one in the dashboard under ' \
                         'Settings → API keys, granting only the scopes this agent needs.'
              }
            }, status: :unauthorized
          end
        end
      end
    end
  end
end

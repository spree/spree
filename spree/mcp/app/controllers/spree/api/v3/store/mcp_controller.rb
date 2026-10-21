module Spree
  module Api
    module V3
      module Store
        # The storefront MCP endpoint: `POST /api/v3/store/mcp`.
        #
        # The shopper's counterpart to {Admin::McpController}, and a separate
        # endpoint rather than a mode of it: one endpoint deciding at runtime
        # whether its caller is a shopper or a merchant is the shape that
        # produces a confused-deputy bug. This one only ever builds a server
        # over {Spree.store_agent_tools}.
        #
        # The publishable key is the whole credential, as it is for the rest
        # of the Store API. It identifies the store, not a person, and a cart
        # is reached through its own token, which the tools carry as the cart
        # id — so a guest is a first-class caller, not a degraded one.
        #
        # See docs/plans/6.1-store-mcp-server.md.
        class McpController < Store::BaseController
          include Spree::Mcp::PublishableKeyInUrl

          def create
            render json: server.handle_json(request.body.read), content_type: 'application/json'
          end

          private

          def server
            Spree::Mcp::Server.for(agent_context, surface: :store)
          end

          # A dispatched tool call authenticates exactly as this request did:
          # the same publishable key, sent the way the Store API reads it —
          # never anything wider minted on the agent's behalf.
          def agent_context
            Spree::AgentTools::Context.new(
              store: current_store,
              api_key: current_api_key,
              request_headers: {
                'HTTP_X_SPREE_API_KEY' => current_api_key.token,
                'HTTP_HOST' => request.host_with_port,
                # Each shopper's agent gets its own rate-limit bucket, as it
                # would calling the Store API directly.
                'REMOTE_ADDR' => request.remote_ip,
                # The Store API resolves and validates it again, so the
                # agent sees the channel's catalog and prices, not the default's.
                'HTTP_X_SPREE_CHANNEL' => request.headers['X-Spree-Channel']
              }.compact
            )
          end
        end
      end
    end
  end
end

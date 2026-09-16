module Spree
  module Mcp
    # Builds an `MCP::Server` for one caller.
    #
    # Per request, not per process. A server carries the tools its caller may
    # use and nothing else — a key minted to read orders is never told a
    # refund tool exists — so the tool list cannot be shared between
    # principals, and the gem's own Rack transport (one server for every
    # request) is not what mounts this. An ordinary admin API controller does,
    # and hands the JSON-RPC message to {MCP::Server#handle_json}.
    module Server
      # What the model is told about using this server at discovery, so it
      # reaches for the discovery tools before guessing at names and filters.
      INSTRUCTIONS = <<~TEXT.freeze
        This server manages one Spree store's back office.

        Start with describe_resource to learn which resources exist and which
        fields each can be filtered and sorted by, then search_resources to find
        records and get_resource to read one in full. For numbers — revenue,
        orders, units — use describe_reporting and then query_report rather than
        counting records yourself.

        Writes are named after what they do: a tool per operation, each running
        the same workflow the dashboard runs, so validations and notifications
        behave identically. Record arguments are prefixed ids as they appear in
        search results. You are only offered the tools this credential permits,
        so a tool you cannot see is one this store has not granted.
      TEXT

      class << self
        # @param context [Spree::AgentTools::Context] who is asking, and where
        # @return [MCP::Server]
        def for(context)
          ::MCP::Server.new(
            name: 'spree-admin',
            title: "#{context.store.name} (Spree admin)",
            version: Spree.version,
            instructions: INSTRUCTIONS,
            tools: tools_for(context),
            server_context: { store_id: context.store.id }
          )
        end

        # The tools this caller may use, as MCP definitions.
        #
        # Filtering happens here rather than at call time, so a tool the
        # credential cannot use is never named to the model — and a call to
        # something it was not offered is "unknown tool", not "forbidden",
        # which says less about what else exists.
        #
        # @param context [Spree::AgentTools::Context]
        # @return [Array<Class<MCP::Tool>>]
        def tools_for(context)
          Spree.agent_tools.available_for(context).map { |tool| ToolAdapter.build(tool) }
        end
      end
    end
  end
end

require 'spree/agent_tools/registry'
require 'spree/agent_tools/context'
require 'spree/agent_tools/resource_map'
require 'spree/agent_tools/record_summary'
require 'spree/agent_tools/workflow_schema'
require 'spree/agent_tools/workflow_tool'
require 'spree/agent_tools/default_catalog'

module Spree
  # The agent-tool contract: what an MCP client or the dashboard assistant may
  # do on a merchant's behalf, and under whose authority.
  #
  # Nothing here talks to a model or a protocol. A tool is a name, a
  # description, a JSON parameter schema, a permission key, a mutating flag
  # and an executor — see {Spree::AgentTool} — and the adapters in `spree_mcp`
  # and the dashboard assistant turn that into their own vocabulary.
  #
  # See docs/plans/6.0-mcp-server.md.
  module AgentTools
  end
end

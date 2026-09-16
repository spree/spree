require 'spree_core'
require 'spree_api'
require 'mcp'

require 'spree/mcp/tool_adapter'
require 'spree/mcp/server'
require 'spree/mcp/engine'

module Spree
  # A Model Context Protocol server for the Spree back office.
  #
  # A thin protocol adapter over {Spree.agent_tools}: the tools, their schemas
  # and the permissions gating them all live in `spree_core`, so this gem adds
  # a transport and nothing else. Optional — an installation that does not
  # want an MCP endpoint simply does not load it.
  #
  # See docs/plans/6.0-mcp-server.md.
  module Mcp
  end
end

# Spree MCP Server

A [Model Context Protocol](https://modelcontextprotocol.io) server for the
Spree back office. Any MCP client — Claude Code, Cursor, an in-house agent —
can merchandise the catalog, answer reporting questions and manage store setup
in plain language, under the same tenancy and permission rules as the Admin
API.

```ruby
gem 'spree_mcp'
```

The endpoint is `POST /api/v3/admin/mcp`, authenticated with a Spree secret API
key sent as `X-Spree-API-Key: sk_…` or `Authorization: Bearer sk_…`. The key's
scopes decide which tools the model is offered, so an agent is never told about
a capability its credential does not carry.

This gem is a protocol adapter and nothing more. The tools, their schemas and
the permissions gating them live in `spree_core` as `Spree.agent_tools`, which
means an extension registers a tool without depending on this gem, and the
dashboard assistant offers the same tools over a different transport.

See the [documentation](https://spreecommerce.org/docs/developer/agentic/admin-mcp)
and `docs/plans/6.0-mcp-server.md`.

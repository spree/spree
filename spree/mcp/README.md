# Spree MCP Server

A [Model Context Protocol](https://modelcontextprotocol.io) server for the
Spree back office. Any MCP client — Claude Code, Cursor, an in-house agent —
can merchandise the catalog, answer reporting questions and manage store setup
in plain language, under the same tenancy and permission rules as the Admin
API.

```bash
spree add mcp   # or add gem 'spree_mcp' to the Gemfile
```

The endpoint is `POST /api/v3/admin/mcp`, authenticated with an OAuth token
issued to a person: the client sends them to the store to sign in and approve
what it may do. The token carries that admin's own permissions, narrowed to
what they approved, and those decide which tools the model is offered, so an
agent is never told about a capability its credential does not carry.

A Spree secret API key (`sk_…`) is deliberately refused here. A nightly job or
a server-side integration has no person behind it; it calls the Admin API with
a key, or uses the `spree api` CLI.

This gem is a protocol adapter and nothing more. The tools, their schemas and
the permissions gating them live in `spree_core` as `Spree.admin_agent_tools`, which
means an extension registers a tool without depending on this gem, and the
dashboard assistant offers the same tools over a different transport.

See the [documentation](https://spreecommerce.org/docs/developer/mcp/overview)
and `docs/plans/6.0-mcp-server.md`.

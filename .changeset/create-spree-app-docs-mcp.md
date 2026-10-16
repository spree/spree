---
"create-spree-app": minor
"@spree/cli": minor
---

Added `spree add ai`, which installs the Spree agent skills and connects Claude Code, Cursor and VS Code to the Spree docs MCP server, so existing projects can get the same AI agent setup as new ones. It keeps the servers a project's config files already list and is safe to re-run. New projects now run it during setup: the agent skills question reads "Set up AI coding agents?" and covers both, and `--docs-mcp` / `--no-docs-mcp` answer the docs half on their own.

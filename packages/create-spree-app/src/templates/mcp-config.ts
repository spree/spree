import { DOCS_MCP_URL } from '../constants.js'

const SERVER_NAME = 'spree-docs'

function json(value: unknown): string {
  return `${JSON.stringify(value, null, 2)}\n`
}

/**
 * Project-level files connecting each coding agent that reads one to the
 * Spree docs MCP server, keyed by their path in the project. Claude Code and
 * Cursor share a format; VS Code names its root `servers` and needs `type`.
 */
export function docsMcpConfigFiles(): Record<string, string> {
  return {
    '.mcp.json': json({ mcpServers: { [SERVER_NAME]: { type: 'http', url: DOCS_MCP_URL } } }),
    '.cursor/mcp.json': json({ mcpServers: { [SERVER_NAME]: { url: DOCS_MCP_URL } } }),
    '.vscode/mcp.json': json({ servers: { [SERVER_NAME]: { type: 'http', url: DOCS_MCP_URL } } }),
  }
}

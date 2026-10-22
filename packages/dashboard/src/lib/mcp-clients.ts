/**
 * The loopback callback a terminal client listens on.
 *
 * Registered alongside the hosted one because Claude Code and Codex redirect
 * to a local port rather than the vendor's servers, and the port is chosen
 * at run time. RFC 8252 §7.3 says to compare loopback redirects ignoring the
 * port, which Doorkeeper does — but only for an IP literal, since it decides
 * by parsing the host as an address. `localhost` is a name, so it parses as
 * nothing and every ephemeral port is refused.
 */
export const LOOPBACK_CALLBACK = 'http://127.0.0.1/callback'

/**
 * The MCP clients the dashboard can fill the callback in for.
 *
 * The redirect URI is where authorization codes are delivered, so a wrong
 * one sends them to whoever controls that host. For the clients we know the
 * merchant should never have to find or type it — they pick a name.
 *
 * `surfaces` are the ways that client connects. A desktop or web app takes
 * the address pasted into its settings; a terminal client takes a command.
 */
export const KNOWN_CLIENTS = [
  {
    value: 'claude',
    name: 'Claude',
    redirectUris: ['https://claude.ai/api/mcp/auth_callback', LOOPBACK_CALLBACK],
    surfaces: [
      { id: 'app', command: null },
      { id: 'cli', command: (url: string) => `claude mcp add --transport http spree ${url}` },
    ],
  },
  {
    value: 'chatgpt',
    name: 'ChatGPT',
    redirectUris: ['https://chatgpt.com/connector_platform_oauth_redirect', LOOPBACK_CALLBACK],
    surfaces: [
      { id: 'app', command: null },
      { id: 'cli', command: (url: string) => `codex mcp add spree --url ${url}` },
    ],
  },
] as const

export type KnownClient = (typeof KNOWN_CLIENTS)[number]

const LOOPBACK_HOSTS = new Set(['127.0.0.1', '[::1]', 'localhost'])

/**
 * The known client a registration's name claims to be, if any. "Claude" and
 * "Claude Desktop" both claim to be Claude; case and surrounding spaces are
 * ignored, since a merchant reading the consent screen ignores them too.
 */
export function knownClientNamed(name: string): KnownClient | undefined {
  const normalized = name.trim().toLowerCase().replace(/\s+/g, ' ')
  return KNOWN_CLIENTS.find((client) => {
    const known = client.name.toLowerCase()
    return normalized === known || normalized.startsWith(`${known} `)
  })
}

/**
 * Where a callback hands the browser back, as the consent screen shows it.
 * Null for a value that is not a URL at all.
 */
export function hostOf(redirectUri: string): string | null {
  try {
    return new URL(redirectUri).host
  } catch {
    return null
  }
}

/**
 * Whether a callback is one the known client publishes, or a loopback
 * address its terminal surface listens on. A registration that borrowed a
 * known name but points anywhere else is how a staffer who may register
 * clients would phish a more privileged colleague's authority.
 */
export function publishedCallback(client: KnownClient, redirectUri: string): boolean {
  const host = hostOf(redirectUri)
  if (host === null) return false
  if (LOOPBACK_HOSTS.has(host.replace(/:\d+$/, ''))) return true
  return client.redirectUris.some((uri) => hostOf(uri) === host)
}

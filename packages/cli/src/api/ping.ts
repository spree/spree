import { createAdminClient, SpreeError } from '@spree/admin-sdk'
import pc from 'picocolors'

export type PingStatus = 'connected' | 'forbidden' | 'unauthorized' | 'unreachable'

export interface PingResult {
  status: PingStatus
  /** Present when the key can read store settings. */
  storeName?: string
  message?: string
}

/**
 * Validates a credential pair with one cheap call. `GET /store` needs
 * `read_settings`, so a 403 still proves the key authenticates — it just
 * lacks that scope; only a 401 means the key itself is invalid.
 */
export async function pingCredentials(baseUrl: string, apiKey: string): Promise<PingResult> {
  const client = createAdminClient({ baseUrl, secretKey: apiKey, retry: false })

  try {
    const store = await client.request<{ name?: string }>('GET', '/store', {})
    return { status: 'connected', storeName: store?.name }
  } catch (error) {
    if (error instanceof SpreeError) {
      // 401 = bad key; 403 = valid key, just lacks read_settings. Any other
      // status means the key authenticated but the server errored — report it
      // distinctly rather than claiming a clean connection.
      if (error.status === 401) return { status: 'unauthorized', message: error.message }
      if (error.status === 403) return { status: 'forbidden' }
      return {
        status: 'unreachable',
        message: `server responded HTTP ${error.status}: ${error.message}`,
      }
    }
    // A non-SpreeError here is a transport failure or a non-JSON response body
    // (e.g. an HTML error page from a proxy) that the SDK couldn't parse.
    const message = error instanceof Error ? error.message : String(error)
    return { status: 'unreachable', message }
  }
}

/** Human-readable, colorized one-liner for a ping result — shared by `spree api status` and `spree auth status`. */
export function formatPingStatus(ping: PingResult): string {
  return {
    connected: pc.green(`connected${ping.storeName ? ` (${ping.storeName})` : ''}`),
    forbidden:
      pc.green('connected') + pc.dim(' (key valid; lacks read_settings for store details)'),
    unauthorized: pc.red('key rejected (401)'),
    unreachable: pc.red(`unreachable — ${ping.message}`),
  }[ping.status]
}

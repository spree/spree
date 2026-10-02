import { presentSections } from './plan.js'
import type { SpreeConfig } from './schema.js'
import { SECTIONS, SOURCES } from './sections/index.js'
import type { ConfigClient } from './types.js'

/**
 * Scopes a deploy of this file needs, deduplicated: each present section's
 * write scope, and the read scope of every section it lists, its own and
 * the ones its references resolve against.
 */
export function requiredScopes(config: SpreeConfig): string[] {
  const scopes = new Set<string>()
  for (const name of presentSections(config)) {
    const section = SECTIONS[name]
    scopes.add(section.scope)
    const referenced = Object.entries(section.references?.(config) ?? {})
      .filter(([, keys]) => keys?.length)
      .map(([target]) => target)
    for (const listed of [name, ...referenced]) scopes.add(SOURCES[listed].readScope)
  }
  return [...scopes]
}

/** Whether a key's scopes grant one scope: `write_x` implies `read_x`, as on the server. */
function grants(held: string[], scope: string): boolean {
  if (held.includes(scope) || held.includes('write_all')) return true
  if (!scope.startsWith('read_')) return false
  return held.includes('read_all') || held.includes(`write_${scope.slice('read_'.length)}`)
}

/**
 * Scopes the key lacks for this file. Null when the key's scopes cannot be
 * read (a JWT principal, an older server), in which case the deploy proceeds
 * and a missing scope surfaces as a 403 on the first request.
 */
export async function missingScopes(
  client: ConfigClient,
  config: SpreeConfig,
): Promise<string[] | null> {
  let scopes: string[] | null
  try {
    const key = await client.request<{ scopes?: string[] | null }>('GET', '/api_keys/current')
    scopes = key.scopes ?? null
  } catch {
    scopes = null
  }
  if (scopes === null) return null
  const held = scopes
  return requiredScopes(config).filter((scope) => !grants(held, scope))
}

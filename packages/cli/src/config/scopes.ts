import { SECTIONS } from './sections/index.js'
import type { ConfigClient, SectionName } from './types.js'

/** Scopes a deploy of these sections needs, deduplicated, in section order. */
export function requiredScopes(sections: SectionName[]): string[] {
  return [...new Set(sections.map((section) => SECTIONS[section].scope))]
}

/**
 * Scopes the key lacks for these sections. Null when the key's scopes cannot
 * be read (a JWT principal, an older server), in which case the deploy
 * proceeds and a missing scope surfaces as a 403 on the first write.
 */
export async function missingScopes(
  client: ConfigClient,
  sections: SectionName[],
): Promise<string[] | null> {
  let scopes: string[] | null
  try {
    const key = await client.request<{ scopes?: string[] | null }>('GET', '/api_keys/current')
    scopes = key.scopes ?? null
  } catch {
    scopes = null
  }
  if (scopes === null) return null
  if (scopes.includes('write_all')) return []
  return requiredScopes(sections).filter((scope) => !scopes.includes(scope))
}

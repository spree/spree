import type { ConfigClient, SectionName } from './types.js'

/** The write scope each section needs on a secret key. */
export const SECTION_SCOPES: Record<SectionName, string> = {
  store: 'write_settings',
  channels: 'write_settings',
  markets: 'write_settings',
  customer_groups: 'write_customers',
  tax_categories: 'write_settings',
  delivery_zones: 'write_settings',
  delivery_methods: 'write_delivery_methods',
  stock_locations: 'write_stock',
  suppliers: 'write_purchasing',
  categories: 'write_categories',
  products: 'write_products',
  customers: 'write_customers',
  sellers: 'write_sellers',
}

/** Scopes a deploy of these sections needs, deduplicated, in section order. */
export function requiredScopes(sections: SectionName[]): string[] {
  return [...new Set(sections.map((section) => SECTION_SCOPES[section]))]
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

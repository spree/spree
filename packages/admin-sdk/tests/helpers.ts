import { createAdminClient } from '../src'

export const BASE_URL = 'https://demo.spreecommerce.org'
export const API_PREFIX = `${BASE_URL}/api/v3/admin`

// Back-compat aliases for existing specs.
export const TEST_BASE_URL = BASE_URL
export const TEST_API_KEY = 'sk_test'

/** A fresh admin client pointed at the mock server. */
export function createTestClient() {
  return createAdminClient({ baseUrl: BASE_URL })
}

/** Wraps a list of records in the standard paginated envelope. */
export const paginated = (data: unknown[]) => ({
  data,
  meta: { page: 1, limit: 25, count: data.length, pages: 1 },
})

import { createClient } from '@spree/sdk'

// One client per request: the API URL and key come from the environment at
// run time, not at build time.
export function spree() {
  const baseUrl = process.env.SPREE_API_URL
  const publishableKey = process.env.SPREE_PUBLISHABLE_KEY
  if (!baseUrl || !publishableKey) {
    throw new Error('Set SPREE_API_URL and SPREE_PUBLISHABLE_KEY.')
  }
  return createClient({ baseUrl, publishableKey })
}

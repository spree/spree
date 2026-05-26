import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Driven entirely by the HttpOnly refresh-token cookie + CSRF header (set by the SDK).
const auth = await client.auth.refresh()
// endregion:example

export { auth }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Soft-deletes the seller. Their products stay in the catalog without a
// seller rather than being deleted with them.
await client.sellers.delete('sel_UkLWZg9DAJ')
// endregion:example

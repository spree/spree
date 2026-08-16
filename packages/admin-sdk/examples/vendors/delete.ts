import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Soft-deletes the vendor. Their products stay in the catalog without a
// seller rather than being deleted with them.
await client.vendors.delete('ven_UkLWZg9DAJ')
// endregion:example

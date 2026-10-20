import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Drafts only: a transfer that has shipped is cancelled instead.
await client.stockTransfers.delete('st_1234567890')

// endregion:example

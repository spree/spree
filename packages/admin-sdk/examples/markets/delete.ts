import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Soft-deletes the market (sets `deleted_at`). The default market and the
// last remaining market in a store cannot be deleted — both return 422.
await client.markets.delete('market_UkLWZg9DAJ')
// endregion:example

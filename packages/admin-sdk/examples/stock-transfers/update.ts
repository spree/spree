import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Drafts only. Sending `items` replaces every line on the transfer.
const transfer = await client.stockTransfers.update('st_1234567890', {
  reference: 'Restock east coast',
  items: [{ variant_id: 'variant_1234567890', quantity_shipped: 24 }],
})

// endregion:example

export { transfer }

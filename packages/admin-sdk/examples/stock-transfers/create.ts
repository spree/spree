import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A draft: nothing moves until the transfer is marked in transit.
const stockTransfer = await client.stockTransfers.create({
  source_location_id: 'sloc_1234567890',
  destination_location_id: 'sloc_0987654321',
  reference: 'Weekly restock',
  items: [{ variant_id: 'variant_1234567890', quantity_shipped: 10 }],
})

// endregion:example

export { stockTransfer }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Once units have left the source, say whether they come back or are written off.
const transfer = await client.stockTransfers.cancel('st_1234567890', {
  on_in_transit: 'write_off',
  reason: 'Lost in transit',
})

// endregion:example

export { transfer }

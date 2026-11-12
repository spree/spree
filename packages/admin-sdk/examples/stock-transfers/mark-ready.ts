import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Freezes the lines; nothing leaves the source shelf until the transfer is sent.
const transfer = await client.stockTransfers.markReady('st_1234567890')

// endregion:example

export { transfer }

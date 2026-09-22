import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The units leave the source warehouse here.
const stockTransfer = await client.stockTransfers.markInTransit('st_1234567890')

// endregion:example

export { stockTransfer }

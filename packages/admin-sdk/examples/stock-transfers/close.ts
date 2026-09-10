import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The missing units are not going to turn up: keep what arrived, record why.
const stockTransfer = await client.stockTransfers.close('st_1234567890', {
  reason: 'Two fell off the van',
})

// endregion:example

export { stockTransfer }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Nothing has left the source yet, so the lines can be changed again.
const stockTransfer = await client.stockTransfers.markDraft('st_1234567890')

// endregion:example

export { stockTransfer }

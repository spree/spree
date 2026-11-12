import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const transfer = await client.stockTransfers.get('st_1234567890', {
  expand: ['items'],
})

// endregion:example

export { transfer }

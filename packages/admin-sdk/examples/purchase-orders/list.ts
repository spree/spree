import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: purchaseOrders } = await client.purchaseOrders.list({
  q: { status_eq: 'ordered' },
  expand: ['supplier'],
})

// endregion:example

export { purchaseOrders }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `customer_ids` is a full-set update — the model reconciles the membership
// to match the array (adds new IDs, removes ones not present).
const group = await client.customerGroups.update('cg_UkLWZg9DAJ', {
  name: 'VIP customers (Q1)',
  customer_ids: ['cus_UkLWZg9DAJ'],
})
// endregion:example

export { group }

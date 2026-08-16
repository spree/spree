import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `status` is not writable here: each move through the lifecycle is its own
// action, because each one does more than set a column.
const vendor = await client.vendors.update('ven_UkLWZg9DAJ', {
  billing_email: 'billing@northwind.example',
  payouts_schedule_interval: 'weekly',
  minimum_payout_amount: '25.0',
})

// endregion:example

export { vendor }

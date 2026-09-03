import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const order = await client.orders.cancel('or_UkLWZg9DAJ', {
  cancel_reason_id: 'ocr_UkLWZg9DAJ',
  cancel_note: 'Supplier could not deliver in time',
  refund_payments: true,
})

// endregion:example

export { order }

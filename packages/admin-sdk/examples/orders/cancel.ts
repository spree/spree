import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A split checkout: the payment is shared, so what comes back is this order's
// own share. refund_amount names part of that share, keeping the rest back.
const order = await client.orders.cancel('or_UkLWZg9DAJ', {
  cancel_reason_id: 'ocr_UkLWZg9DAJ',
  cancel_note: 'Supplier could not deliver in time',
  refund_payments: true,
  refund_amount: '25.00',
})

// endregion:example

export { order }

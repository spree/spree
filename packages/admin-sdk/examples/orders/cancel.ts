import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const order = await client.orders.cancel('or_UkLWZg9DAJ', {
  cancel_reason_id: 'ocr_UkLWZg9DAJ',
  cancel_note: 'Supplier could not deliver in time',
  // On a split checkout, hand back this order's share of the shared payment.
  // Omit refund_amount to return the whole share.
  refund_payments: true,
  refund_amount: '25.00',
})

// endregion:example

export { order }

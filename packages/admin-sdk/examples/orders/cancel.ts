import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A split checkout: the payment is shared, so this hands back only this
// order's share of it.
const order = await client.orders.cancel('or_UkLWZg9DAJ', {
  cancel_reason_id: 'ocr_UkLWZg9DAJ',
  cancel_note: 'Supplier could not deliver in time',
  // Omit refund_amount to return the whole share. It is refused on an
  // ordinary order, where the gateway returns the payment in full.
  refund_payments: true,
  refund_amount: '25.00',
})

// endregion:example

export { order }

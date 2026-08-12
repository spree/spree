import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Splitting moves a quantity of one variant into its own fulfillment, so the
// response is the order's full set: the source is re-shaped, and disappears
// when the split drains it. Pass stock_location_id to send the new
// fulfillment out from a different origin.
const { data: fulfillments } = await client.orders.fulfillments.split(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  {
    variant_id: 'variant_86Rf07xd4z',
    quantity: 1,
  },
)

// endregion:example

export { fulfillments }

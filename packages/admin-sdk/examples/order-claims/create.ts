import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The customer keeps the goods: nothing comes back, so no return is opened.
const claim = await client.orders.claims.create('or_UkLWZg9DAJ', {
  reason_id: 'clr_UkLWZg9DAJ',
  memo: 'Arrived with a cracked lid',
  items: [
    {
      line_item_id: 'li_UkLWZg9DAJ',
      quantity: 1,
      description: 'Lid cracked in transit',
      send_replacement: true,
    },
  ],
})

// endregion:example

export { claim }

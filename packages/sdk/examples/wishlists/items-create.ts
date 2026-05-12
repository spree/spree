import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const item = await client.wishlists.items.create('wl_abc123', {
  variant_id: 'variant_abc123',
  quantity: 1,
}, {
  token: '<token>',
})
// endregion:example

export { item }

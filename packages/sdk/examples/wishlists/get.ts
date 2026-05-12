import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const wishlist = await client.wishlists.get('wl_abc123', {
  expand: ['wished_items'],
}, {
  token: '<token>',
})
// endregion:example

export { wishlist }

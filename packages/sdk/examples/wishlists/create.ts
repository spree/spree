import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const wishlist = await client.wishlists.create({
  name: 'Birthday Ideas',
  is_private: true,
}, {
  token: '<token>',
})
// endregion:example

export { wishlist }

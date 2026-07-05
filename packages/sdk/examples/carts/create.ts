import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// Create an empty cart
const cart = await client.carts.create()

// Create a cart with items
const cartWithItems = await client.carts.create({
  items: [
    { variant_id: 'variant_abc123', quantity: 2 },
  ],
})
// endregion:example

export { cart, cartWithItems }

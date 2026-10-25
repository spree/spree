import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const addresses = await client.carts.addresses.list(
  'cart_abc123',
  {},
  {
    token: '<token>',
  },
)

// endregion:example

export { addresses }

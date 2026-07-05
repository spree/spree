import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const cart = await client.carts.update('cart_abc123', {
  email: 'customer@example.com',
  shipping_address: {
    first_name: 'John',
    last_name: 'Doe',
    address1: '123 Main St',
    city: 'New York',
    postal_code: '10001',
    country_iso: 'US',
    state_abbr: 'NY',
  },
}, {
  token: '<token>',
})
// endregion:example

export { cart }

import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const carts = await client.carts.list({
  token: '<token>',
})
// endregion:example

export { carts }

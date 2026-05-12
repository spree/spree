import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const auth = await client.auth.login({
  email: 'customer@example.com',
  password: 'password123',
})
// endregion:example

export { auth }

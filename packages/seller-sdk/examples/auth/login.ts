import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
})

// region:example
const auth = await client.auth.login({
  email: 'seller@example.com',
  password: 'password123',
})

// endregion:example

export { auth }

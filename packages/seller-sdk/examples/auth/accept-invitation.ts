import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
})

// region:example
const auth = await client.auth.acceptInvitation('inv_xxx', 'token-from-email', {
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Jane',
  last_name: 'Doe',
})

// endregion:example

export { auth }

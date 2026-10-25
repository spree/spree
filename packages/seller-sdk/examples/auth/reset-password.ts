import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
})

// region:example
const auth = await client.auth.resetPassword('reset-token-from-email', {
  password: 'new-password-123',
  password_confirmation: 'new-password-123',
})

// endregion:example

export { auth }

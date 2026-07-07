import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The token comes from the emailed link's ?token= param. On success the admin
// is signed in: a JWT comes back and the refresh token is set as an HttpOnly cookie.
const auth = await client.auth.resetPassword('reset-token-from-email', {
  password: 'new-password-123',
  password_confirmation: 'new-password-123',
})

// endregion:example

export { auth }

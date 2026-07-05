import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The refresh token is set as an HttpOnly cookie; only `token` and `user` come back in the body.
const auth = await client.auth.login({
  email: 'admin@example.com',
  password: 'password123',
})
// endregion:example

export { auth }

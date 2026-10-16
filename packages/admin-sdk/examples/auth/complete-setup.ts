import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The setup token is printed when Spree is installed. The refresh token is
// set as an HttpOnly cookie; only `token` and `user` come back in the body.
const auth = await client.auth.completeSetup({
  setup_token: 'st_9f2c4e7a1b8d',
  email: 'owner@example.com',
  password: 'Secret123!',
  password_confirmation: 'Secret123!',
  first_name: 'Olivia',
  last_name: 'Owner',
  store_name: 'My Store',
  country_code: 'US',
})

// endregion:example

export { auth }

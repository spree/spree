import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const auth = await client.passwordResets.update(
  'reset-token-from-email',
  {
    password: 'newsecurepassword',
    password_confirmation: 'newsecurepassword',
  }
)
// endregion:example

export { auth }

import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
await client.passwordResets.create({
  email: 'customer@example.com',
  redirect_url: 'https://myshop.com/reset-password',
})
// endregion:example

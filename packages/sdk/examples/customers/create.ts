import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const auth = await client.customers.create({
  email: 'newuser@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'John',
  last_name: 'Doe',
  phone: '+1234567890',
  accepts_email_marketing: true,
  metadata: { source: 'storefront' },
})
// endregion:example

export { auth }

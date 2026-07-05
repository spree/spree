import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const customer = await client.customers.create({
  email: 'jane@example.com',
  first_name: 'Jane',
  last_name: 'Doe',
  phone: '+1 212 555 1234',
  tags: ['wholesale'],
  accepts_email_marketing: true,
})
// endregion:example

export { customer }

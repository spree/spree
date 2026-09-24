import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// Always an emailed invitation (cinv_…), even for an existing customer.
const invitation = await client.companies.members.create(
  'comp_86Rf07xd4z',
  { customer_email: 'colleague@acme.test' },
  { token: '<token>' },
)

// endregion:example

export { invitation }

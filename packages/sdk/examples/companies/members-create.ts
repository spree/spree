import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// An existing customer joins immediately (cmem_…); anyone else is emailed an
// invitation (cinv_…).
const member = await client.companies.members.create(
  'comp_86Rf07xd4z',
  { customer_email: 'colleague@acme.test' },
  { token: '<token>' },
)

// endregion:example

export { member }

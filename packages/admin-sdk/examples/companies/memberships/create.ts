import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// An existing customer becomes a member immediately; an unknown email
// becomes an invitation (check the returned id prefix: cmem_ vs cinv_).
const member = await client.companies.memberships.create('comp_86Rf07xd4z', {
  customer_email: 'buyer@example.com',
})

// endregion:example

export { member }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: members } = await client.companies.memberships.list('comp_86Rf07xd4z')

// endregion:example

export { members }

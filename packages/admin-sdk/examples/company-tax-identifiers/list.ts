import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: registrations } = await client.companies.taxIdentifiers.list('comp_UkLWZg9DAJ')

// endregion:example

export { registrations }

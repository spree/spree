import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: companies } = await client.companies.list({ name_cont: 'Acme' })

// endregion:example

export { companies }

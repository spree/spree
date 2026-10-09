import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: suppliers } = await client.suppliers.list({ search: 'Acme' })

// endregion:example

export { suppliers }

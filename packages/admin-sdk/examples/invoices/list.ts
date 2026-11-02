import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: invoices } = await client.invoices.list({ kind_eq: 'invoice' })

// endregion:example

export { invoices }

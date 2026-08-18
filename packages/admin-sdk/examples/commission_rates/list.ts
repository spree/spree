import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Rates come back with their targeting attached. A rate holding no rules
// applies to every sale.
const { data: commissionRates } = await client.commissionRates.list({ page: 1, limit: 25 })

// endregion:example

export { commissionRates }

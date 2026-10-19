import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const taxRate = await client.taxRates.update('tax_UkLWZg9DAJ', { rate_percent: '7' })

// endregion:example

export { taxRate }

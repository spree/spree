import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const taxRate = await client.taxRates.get('tax_UkLWZg9DAJ')

// endregion:example

export { taxRate }

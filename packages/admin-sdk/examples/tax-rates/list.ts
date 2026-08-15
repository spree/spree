import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: taxRates } = await client.taxRates.list({ country_code_eq: 'DE' })

// endregion:example

export { taxRates }

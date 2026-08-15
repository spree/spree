import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A rate names the jurisdiction it applies to; one naming no country taxes everywhere.
const taxRate = await client.taxRates.create({
  name: 'German VAT',
  amount: 0.19,
  country_code: 'DE',
  tax_category_id: 'txc_UkLWZg9DAJ',
  included_in_price: true,
})

// endregion:example

export { taxRate }

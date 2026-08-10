import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A business registration outranks the buyer's own when the sale is for that business.
const registration = await client.companies.taxIdentifiers.create('comp_UkLWZg9DAJ', {
  kind: 'eu_vat',
  value: 'DE123456789',
})

// endregion:example

export { registration }

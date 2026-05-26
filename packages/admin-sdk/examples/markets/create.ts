import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const market = await client.markets.create({
  name: 'Europe',
  currency: 'EUR',
  default_locale: 'de',
  supported_locales: ['de', 'en', 'fr'],
  tax_inclusive: true,
  country_isos: ['DE', 'FR', 'IT'],
})
// endregion:example

export { market }

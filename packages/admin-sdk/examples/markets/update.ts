import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// `country_codes` is a full-set update — the market is reconciled to match
// the array (adds new countries, removes ones not present). Setting
// `default: true` demotes the previous default market in the store.
const market = await client.markets.update('market_UkLWZg9DAJ', {
  name: 'European Union',
  tax_inclusive: true,
  country_codes: ['DE', 'FR'],
})

// endregion:example

export { market }

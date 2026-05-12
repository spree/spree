import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const countries = await client.markets.countries.list('mkt_xxx')
// endregion:example

export { countries }

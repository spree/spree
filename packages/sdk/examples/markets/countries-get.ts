import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const country = await client.markets.countries.get('mkt_xxx', 'DE')
// endregion:example

export { country }

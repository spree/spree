import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const country = await client.countries.get('US')
// endregion:example

export { country }

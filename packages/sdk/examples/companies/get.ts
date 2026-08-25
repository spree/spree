import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const company = await client.companies.get('comp_86Rf07xd4z', { token: '<token>' })

// endregion:example

export { company }

import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const policy = await client.policies.get('return-policy')
// endregion:example

export { policy }

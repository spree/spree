import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const auth = await client.auth.refresh({
  refresh_token: 'rt_xxx',
})
// endregion:example

export { auth }

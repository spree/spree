import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const categories = await client.categories.list({
  page: 1,
  limit: 25,
})
// endregion:example

export { categories }

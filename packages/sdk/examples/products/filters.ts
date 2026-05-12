import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const filters = await client.products.filters({
  category_id: 'ctg_abc123',
})
// endregion:example

export { filters }

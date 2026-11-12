import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// How much of each product is translated into each of the store's other languages.
const { data: coverage } = await client.translations.coverage('product', {
  search: 'espresso',
  limit: 25,
})

// endregion:example

export { coverage }

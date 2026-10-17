import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Moves the product to the top of the collection; positions are 0-based.
await client.collections.products.reposition('coll_UkLWZg9DAJ', 'prod_UkLWZg9DAJ', {
  new_position: 0,
})

// endregion:example

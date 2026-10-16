import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Moves the product to the top of the category; positions are 0-based.
await client.categories.products.reposition('ctg_UkLWZg9DAJ', 'prod_UkLWZg9DAJ', {
  new_position: 0,
})

// endregion:example

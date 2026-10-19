import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Moves the category under a new parent, as its first child.
const category = await client.categories.reposition('ctg_gbHJdmfrXB', {
  new_parent_id: 'ctg_UkLWZg9DAJ',
  new_position: 0,
})

// endregion:example

export { category }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Backfills the type's option types and categories onto products that already have it.
const result = await client.productTypes.applyToProducts('pt_UkLWZg9DAJ')

// endregion:example

export { result }

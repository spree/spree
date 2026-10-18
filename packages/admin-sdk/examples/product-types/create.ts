import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Products created with this type start with its option types and categories.
const productType = await client.productTypes.create({
  name: 'Hoodie',
  option_type_ids: ['opt_UkLWZg9DAJ'],
  category_ids: ['ctg_UkLWZg9DAJ'],
})

// endregion:example

export { productType }

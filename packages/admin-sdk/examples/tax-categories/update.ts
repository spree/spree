import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Making a category the default moves the flag off the previous one.
const taxCategory = await client.taxCategories.update('taxcat_UkLWZg9DAJ', {
  name: 'Apparel',
  is_default: true,
})

// endregion:example

export { taxCategory }

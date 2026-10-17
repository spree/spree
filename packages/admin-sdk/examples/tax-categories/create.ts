import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const taxCategory = await client.taxCategories.create({
  name: 'Food',
  tax_code: 'PF050000',
  description: 'Groceries and prepared food',
})

// endregion:example

export { taxCategory }

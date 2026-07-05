import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const credit = await client.customers.storeCredits.create('cus_UkLWZg9DAJ', {
  amount: '25.00',
  currency: 'USD',
  category_id: 'cat_UkLWZg9DAJ',
  memo: 'Goodwill credit',
})

// endregion:example

export { credit }

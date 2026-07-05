import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: storeCredits } = await client.customers.storeCredits.list('cus_UkLWZg9DAJ')
// endregion:example

export { storeCredits }

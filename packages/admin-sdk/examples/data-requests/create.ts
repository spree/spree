import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const dataRequest = await client.dataRequests.create({
  customer_id: 'cus_UkLWZg9DAJ',
  kind: 'access',
})

// endregion:example

export { dataRequest }

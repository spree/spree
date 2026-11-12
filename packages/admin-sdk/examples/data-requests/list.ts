import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: dataRequests } = await client.dataRequests.list({
  kind_eq: 'erasure',
  sort: '-requested_at',
})

// endregion:example

export { dataRequests }

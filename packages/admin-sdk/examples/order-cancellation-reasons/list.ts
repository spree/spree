import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: reasons } = await client.orderCancellationReasons.list()

// endregion:example

export { reasons }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const reason = await client.returnReasons.create({
  name: 'Damaged in transit',
})

// endregion:example

export { reason }

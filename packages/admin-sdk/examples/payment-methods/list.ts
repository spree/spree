import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: paymentMethods } = await client.paymentMethods.list()
// endregion:example

export { paymentMethods }

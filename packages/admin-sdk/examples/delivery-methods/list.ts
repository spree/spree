import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: deliveryMethods } = await client.deliveryMethods.list()

// endregion:example

export { deliveryMethods }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: deliveryZones } = await client.deliveryZones.list({ name_cont: 'US' })

// endregion:example

export { deliveryZones }

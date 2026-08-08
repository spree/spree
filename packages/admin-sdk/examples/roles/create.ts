import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const role = await client.roles.create({
  name: 'order_manager',
  description: 'Handles daily orders',
  permissions: ['write_orders', 'read_customers'],
})

// endregion:example

export { role }

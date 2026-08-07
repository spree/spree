import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const role = await client.roles.update('role_abc123', {
  permissions: ['write_orders', 'write_payments', 'read_customers'],
})

// endregion:example

export { role }

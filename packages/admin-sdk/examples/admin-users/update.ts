import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const staff = await client.adminUsers.update('admin_xxx', {
  first_name: 'Ada',
  role_ids: ['role_xxx']
})
// endregion:example

export { staff }

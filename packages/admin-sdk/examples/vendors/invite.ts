import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// They join the vendor's team when they accept, and can then sign in to the
// vendor panel. Omit `role_id` for the vendor's own admin role.
const vendor = await client.vendors.invite('ven_UkLWZg9DAJ', {
  email: 'seller@northwind.example',
})

// endregion:example

export { vendor }

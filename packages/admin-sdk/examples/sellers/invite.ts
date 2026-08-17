import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// They join the seller's team when they accept, and can then sign in to the
// seller panel. Omit `role_id` for the seller's own admin role.
const seller = await client.sellers.invite('sel_UkLWZg9DAJ', {
  email: 'seller@northwind.example',
})

// endregion:example

export { seller }

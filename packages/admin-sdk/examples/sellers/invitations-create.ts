import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Adds someone to the seller's team without changing the seller's status.
const invitation = await client.sellers.invitations.create('sel_UkLWZg9DAJ', {
  email: 'teammate@northwind.example',
})

// endregion:example

export { invitation }

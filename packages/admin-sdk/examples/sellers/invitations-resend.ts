import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const invitation = await client.sellers.invitations.resend('seller_UkLWZg9DAJ', 'inv_UkLWZg9DAJ')

// endregion:example

export { invitation }

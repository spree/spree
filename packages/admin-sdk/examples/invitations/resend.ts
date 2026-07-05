import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const invitation = await client.invitations.resend('inv_xxx')
// endregion:example

export { invitation }

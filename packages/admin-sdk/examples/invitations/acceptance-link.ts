import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { acceptance_url } = await client.invitations.acceptanceLink('inv_xxx')

// endregion:example

export { acceptance_url }

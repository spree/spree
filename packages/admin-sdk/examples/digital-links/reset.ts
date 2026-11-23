import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const digitalLink = await client.digitalLinks.reset('dl_xxx')

// endregion:example

export { digitalLink }

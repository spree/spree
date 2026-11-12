import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// True only until the installation has its first admin user.
const { setup_required } = await client.auth.setupStatus()

// endregion:example

export { setup_required }

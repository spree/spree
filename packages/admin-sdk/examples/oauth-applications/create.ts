import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const application = await client.oauth.applications.create({
  name: 'Claude',
  redirect_uri: 'https://claude.ai/api/mcp/auth_callback',
})

// endregion:example

export { application }

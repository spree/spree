import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const application = await client.oauth.applications.update('oap_UkLWZg9DAJ', {
  name: 'Claude Desktop',
})

// endregion:example

export { application }

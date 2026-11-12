import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.oauth.applications.tokens.delete('oap_UkLWZg9DAJ', 'oat_gbHJdmfrXB')

// endregion:example

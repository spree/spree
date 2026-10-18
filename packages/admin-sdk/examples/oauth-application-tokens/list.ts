import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: connections } = await client.oauth.applications.tokens.list('oap_UkLWZg9DAJ', {
  expand: ['owner'],
})

// endregion:example

export { connections }

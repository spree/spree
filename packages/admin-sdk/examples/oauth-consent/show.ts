import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const request = await client.oauth.authorization({
  client_id: 'abc123',
  redirect_uri: 'https://claude.ai/api/mcp/auth_callback',
  response_type: 'code',
  scope: 'read_products write_orders',
  code_challenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
  code_challenge_method: 'S256',
})

// endregion:example

export { request }

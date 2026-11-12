import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const integration = await client.integrations.update('int_UkLWZg9DAJ', {
  active: true,
  preferences: { account_number: 'demo-0001' },
})

// endregion:example

export { integration }

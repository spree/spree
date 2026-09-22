import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const storeCredit = await client.storeCredits.get('credit_abc123', {
  expand: ['customer', 'created_by'],
})

// endregion:example

export { storeCredit }

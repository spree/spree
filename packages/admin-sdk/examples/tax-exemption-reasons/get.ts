import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const reason = await client.taxExemptionReasons.get('txr_UkLWZg9DAJ')

// endregion:example

export { reason }

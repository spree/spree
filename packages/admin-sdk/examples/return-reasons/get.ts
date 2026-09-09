import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const reason = await client.returnReasons.get('rar_UkLWZg9DAJ')

// endregion:example

export { reason }

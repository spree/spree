import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const reason = await client.orderCancellationReasons.get('ocr_UkLWZg9DAJ')

// endregion:example

export { reason }

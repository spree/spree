import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const reason = await client.orderCancellationReasons.update('ocr_UkLWZg9DAJ', {
  active: false,
})

// endregion:example

export { reason }

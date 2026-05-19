import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const batch = await client.giftCardBatches.get('gcb_K3zr8x')
// endregion:example

export { batch }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const paymentMethod = await client.paymentMethods.create({
  type: 'check',
  name: 'Bank transfer',
  description: 'Pay by bank transfer within 14 days.',
  active: true,
  storefront_visible: true,
  capture_method: 'manual',
})

// endregion:example

export { paymentMethod }

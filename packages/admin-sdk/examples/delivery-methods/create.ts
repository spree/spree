import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const deliveryMethod = await client.deliveryMethods.create({
  name: 'Express',
  storefront_visible: true,
  calculator: { type: 'flat_rate', preferences: { amount: '12.50' } },
})

// endregion:example

export { deliveryMethod }

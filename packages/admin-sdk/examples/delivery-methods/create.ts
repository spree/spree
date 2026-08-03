import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const deliveryMethod = await client.deliveryMethods.create({
  name: 'Express',
  fulfillment_type: 'shipping',
  storefront_visible: true,
  calculator_type: 'Spree::Calculator::Shipping::FlatRate',
  calculator_preferences: { amount: 12.5 },
})

// endregion:example

export { deliveryMethod }

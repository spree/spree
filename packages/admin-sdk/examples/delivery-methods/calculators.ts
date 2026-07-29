import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: calculators } = await client.deliveryMethods.calculators()

// endregion:example

export { calculators }

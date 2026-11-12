import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const rule = await client.deliveryMethods.rules.update('dm_UkLWZg9DAJ', 'dmrule_UkLWZg9DAJ', {
  active: false,
  preferences: { minimum_amount: '40.00', maximum_amount: '500.00' },
})

// endregion:example

export { rule }

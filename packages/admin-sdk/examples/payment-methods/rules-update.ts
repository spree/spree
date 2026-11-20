import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const rule = await client.paymentMethods.rules.update('pm_UkLWZg9DAJ', 'pmrule_gbHJdmfrXB', {
  active: false,
})

// endregion:example

export { rule }

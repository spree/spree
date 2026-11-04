import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
await client.paymentMethods.rules.delete('pm_UkLWZg9DAJ', 'pmrule_gbHJdmfrXB')

// endregion:example

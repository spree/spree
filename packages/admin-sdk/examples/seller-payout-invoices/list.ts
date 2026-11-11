import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: invoices } = await client.sellerPayouts.invoices.list('vpo_UkLWZg9DAJ')

// endregion:example

export { invoices }

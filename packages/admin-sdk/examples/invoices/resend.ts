import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const invoice = await client.invoices.resend('inv_UkLWZg9DAJ')

// endregion:example

export { invoice }

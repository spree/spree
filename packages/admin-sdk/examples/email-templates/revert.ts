import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Goes back to Spree's default. Published versions stay in the history.
const template = await client.emailTemplates.revert('spree.order_mailer.confirm_email')

// endregion:example

export { template }

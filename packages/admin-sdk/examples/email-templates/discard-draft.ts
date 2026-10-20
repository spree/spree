import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const template = await client.emailTemplates.draft.delete('spree.order_mailer.confirm_email')

// endregion:example

export { template }

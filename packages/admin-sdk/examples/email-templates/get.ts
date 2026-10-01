import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const template = await client.emailTemplates.get('spree.order_mailer.confirm_email', {
  language: 'de',
  expand: ['draft.updated_by'],
})

// endregion:example

export { template }

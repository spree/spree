import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const revisions = await client.emailTemplates.revisions.list('spree.order_mailer.confirm_email', {
  expand: ['published_by'],
})

// endregion:example

export { revisions }

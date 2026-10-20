import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Copies the revision into the draft, to publish like any change.
const template = await client.emailTemplates.revisions.restore(
  'spree.order_mailer.confirm_email',
  'etrv_k5nR8xLq',
)

// endregion:example

export { template }

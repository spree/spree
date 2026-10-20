import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Pass the lock_version the draft was loaded with: a save made from an
// older copy is refused with 409, naming who saved last.
const template = await client.emailTemplates.draft.update('spree.order_mailer.confirm_email', {
  subject: 'Your order {{ order.number }} is confirmed',
  body: '<mj-section><mj-column><mj-text>Thanks, {{ order.customer_name }}!</mj-text></mj-column></mj-section>',
  lock_version: 0,
})

// endregion:example

export { template }

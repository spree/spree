import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Always sent to the signed-in admin.
const { sent_to } = await client.emailTemplates.sendTest('spree.order_mailer.confirm_email', {
  body: '<mj-section><mj-column><mj-text>Thanks, {{ order.customer_name }}!</mj-text></mj-column></mj-section>',
})

// endregion:example

export { sent_to }

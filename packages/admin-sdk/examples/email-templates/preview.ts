import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const preview = await client.emailTemplates.preview('spree.order_mailer.confirm_email', {
  body: '<mj-section><mj-column><mj-text>Thanks, {{ order.customer_name }}!</mj-text></mj-column></mj-section>',
  record_id: 'or_m3Rp9wXz',
})

// endregion:example

export { preview }

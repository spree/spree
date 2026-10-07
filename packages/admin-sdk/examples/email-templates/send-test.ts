import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
})

// region:example
// Sent to the signed-in admin, so this needs a client created with `jwtToken`;
// a secret key has no inbox and is refused.
const { sent_to } = await client.emailTemplates.sendTest('spree.order_mailer.confirm_email', {
  body: '<mj-section><mj-column><mj-text>Thanks, {{ order.customer_name }}!</mj-text></mj-column></mj-section>',
})

// endregion:example

export { sent_to }

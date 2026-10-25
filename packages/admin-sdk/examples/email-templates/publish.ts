import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Refused with 422 and each problem's email and line when the draft does not render.
const template = await client.emailTemplates.publish('spree.order_mailer.confirm_email')

// endregion:example

export { template }

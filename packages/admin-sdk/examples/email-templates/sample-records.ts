import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The latest orders to preview the order confirmation with; pass one's id as `record_id`.
const { data: records } = await client.emailTemplates.sampleRecords.list(
  'spree.order_mailer.confirm_email',
)

// endregion:example

export { records }

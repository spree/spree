import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Excuses this seller from a requirement every other seller still has to meet.
const submission = await client.sellers.requirementSubmissions.waive('sel_UkLWZg9DAJ', {
  requirement_id: 'selreq_UkLWZg9DAJ',
  review_note: 'Registered charity, exempt from the business licence check.',
})

// endregion:example

export { submission }

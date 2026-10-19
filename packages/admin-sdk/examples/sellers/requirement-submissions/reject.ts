import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The review note is sent back to the seller as the reason.
const submission = await client.sellers.requirementSubmissions.reject(
  'sel_UkLWZg9DAJ',
  'selsub_UkLWZg9DAJ',
  { review_note: 'The document has expired. Please upload a current one.' },
)

// endregion:example

export { submission }

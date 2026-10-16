import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const submission = await client.sellers.requirementSubmissions.accept(
  'sel_UkLWZg9DAJ',
  'selsub_UkLWZg9DAJ',
  { review_note: 'Licence verified with the issuing authority.' },
)

// endregion:example

export { submission }

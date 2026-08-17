import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// For an applicant who never traded. A seller already selling is suspended
// instead.
const seller = await client.sellers.reject('sel_UkLWZg9DAJ', {
  reason: 'Incomplete paperwork',
})

// endregion:example

export { seller }

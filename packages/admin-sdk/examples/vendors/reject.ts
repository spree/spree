import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// For an applicant who never traded. A vendor already selling is suspended
// instead.
const vendor = await client.vendors.reject('ven_UkLWZg9DAJ', {
  reason: 'Incomplete paperwork',
})

// endregion:example

export { vendor }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const publication = await client.categories.publications.update(
  'ctg_UkLWZg9DAJ',
  'ctgpub_UkLWZg9DAJ',
  { unpublished_at: '2027-01-15T00:00:00Z' },
)

// endregion:example

export { publication }

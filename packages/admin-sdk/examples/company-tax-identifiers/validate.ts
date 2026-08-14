import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A registry answers only "valid now", so a number verified last year may
// have been deregistered since. The check is queued; poll for the verdict.
const registration = await client.companies.taxIdentifiers.validate(
  'comp_UkLWZg9DAJ',
  'txi_UkLWZg9DAJ',
)

// endregion:example

export { registration }

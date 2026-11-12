import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const certificate = await client.companies.taxExemptionCertificates.update(
  'comp_UkLWZg9DAJ',
  'cert_k5nR8xLqPz',
  { issuing_authority: 'Finanzamt Berlin', expires_at: '2027-12-31T23:59:59Z' },
)

// endregion:example

export { certificate }

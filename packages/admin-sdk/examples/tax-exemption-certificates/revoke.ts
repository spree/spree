import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// A verified certificate cannot be deleted — how a sale was taxed has to stay
// explainable — so revoking is the way out.
const certificate = await client.companies.taxExemptionCertificates.revoke(
  'comp_UkLWZg9DAJ',
  'cert_UkLWZg9DAJ',
)

// endregion:example

export { certificate }

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Accepting is what makes a certificate exempt sales. Only a pending one can
// be accepted, and an installation's own checks can refuse here.
const certificate = await client.companies.taxExemptionCertificates.verify(
  'comp_UkLWZg9DAJ',
  'cert_UkLWZg9DAJ',
)

// endregion:example

export { certificate }

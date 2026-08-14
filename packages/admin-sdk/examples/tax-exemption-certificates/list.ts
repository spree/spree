import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: certificates } =
  await client.companies.taxExemptionCertificates.list('comp_UkLWZg9DAJ')

// `active` — not `status` — answers whether one exempts a sale: a verified
// certificate stops counting once its expiry date passes.
const applying = certificates.filter((certificate) => certificate.active)

// endregion:example

export { applying, certificates }

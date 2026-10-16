import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const { data: groups } =
  await client.companies.taxExemptionCertificates.reasonCodes('comp_UkLWZg9DAJ')

// One group per installed tax provider; record a code from the group of the
// provider that calculates this store's tax.
const reasonCodes = groups.flatMap((group) => group.reason_codes)

// endregion:example

export { groups, reasonCodes }

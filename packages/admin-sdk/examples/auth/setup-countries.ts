import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Each country comes with the currency and languages the store would start with.
const { countries } = await client.auth.setupCountries()

// endregion:example

export { countries }

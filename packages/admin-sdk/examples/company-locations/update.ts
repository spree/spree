import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Address fields edit the branch's existing address in place.
const location = await client.companyLocations.update('cloc_UkLWZg9DAJ', {
  name: 'Berlin Mitte',
  billing_address: { city: 'Berlin' },
})

// endregion:example

export { location }

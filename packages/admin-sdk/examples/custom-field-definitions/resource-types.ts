import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// What a definition can be attached to. Comes from the server's registry, so
// a resource an extension adds shows up here without a client release.
const { data: resourceTypes } = await client.customFieldDefinitions.resourceTypes()

// endregion:example

export { resourceTypes }

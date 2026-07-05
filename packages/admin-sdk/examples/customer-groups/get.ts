import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Pass `expand: ['customers']` to embed the group's customers in the response
// — omit it for the much smaller index-payload shape.
const group = await client.customerGroups.get('cg_UkLWZg9DAJ', { expand: ['customers'] })
// endregion:example

export { group }

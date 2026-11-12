import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Check where a file is used before deleting it.
const { data: usage } = await client.media.usage('media_UkLWZg9DAJ')

// endregion:example

export { usage }

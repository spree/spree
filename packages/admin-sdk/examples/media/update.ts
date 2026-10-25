import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const media = await client.media.update('media_UkLWZg9DAJ', {
  alt: 'Folded on a table',
})

// endregion:example

export { media }

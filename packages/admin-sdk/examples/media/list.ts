import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Library images that are not used anywhere yet.
const { data: media } = await client.media.list({
  unattached: true,
  media_type_eq: 'image',
  limit: 25,
})

// endregion:example

export { media }

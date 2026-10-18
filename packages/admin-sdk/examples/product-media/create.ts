import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Places a library file on the product. The file is shared, not copied.
const media = await client.products.media.create('prod_UkLWZg9DAJ', {
  source_media_id: 'media_UkLWZg9DAJ',
  alt: 'Front view',
})

// endregion:example

export { media }

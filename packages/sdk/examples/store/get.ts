import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
  locale: 'de',
})

// region:example
const store = await client.store.get()

const title = store.seo_title ?? store.name
const description = store.meta_description

// endregion:example

export { description, store, title }

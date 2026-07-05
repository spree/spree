import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const subscriber = await client.newsletterSubscribers.create({
  email: 'subscriber@example.com',
  redirect_url: 'https://your-store.com/newsletter/confirm',
})
// endregion:example

export { subscriber }

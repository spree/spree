import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
const subscriber = await client.newsletterSubscribers.create({
  email: 'subscriber@example.com',
  // Where the verification token should land. Must be in the store's
  // allowed origins. The storefront's webhook handler will send the
  // confirmation email with a link to `<redirect_url>?token=<token>`.
  redirect_url: 'https://your-store.com/newsletter/confirm',
})
// endregion:example

export { subscriber }

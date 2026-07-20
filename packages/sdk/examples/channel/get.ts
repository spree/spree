import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
  // Optional: resolve a specific channel; omit to use the API key's
  // bound channel or the store default.
  channel: 'wholesale',
})

// region:example
const channel = await client.channel.get()

if (channel.storefront_access === 'login_required') {
  // render a sign-in wall before any catalog UI
}

// endregion:example

export { channel }

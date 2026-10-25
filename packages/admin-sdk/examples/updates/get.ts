import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
})

// region:example
// Needs a client created with `jwtToken`: a secret key is refused.
const status = await client.updates.get()
if (status.update_available) {
  console.log(`Spree ${status.latest_version} is available: ${status.latest_release_url}`)
}

// endregion:example

export { status }

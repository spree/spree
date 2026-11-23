import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
})

// region:example
// Needs a client created with `jwtToken`: a secret key is refused.
const report = await client.diagnostics.get()
console.log(report.markdown)

// endregion:example

export { report }

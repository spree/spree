import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Always resolves (202) whether or not the email exists — no account enumeration.
// The emailed link points at redirect_url with the reset token appended as ?token=.
await client.auth.requestPasswordReset({
  email: 'admin@example.com',
  redirect_url: 'https://admin.your-store.com/reset-password',
})
// endregion:example

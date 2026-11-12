import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The invitation ID and token come from the link in the invitation email.
// An invitee without an account sets a password here; one with an account
// signs in with theirs. The refresh token is set as an HttpOnly cookie.
const auth = await client.auth.acceptInvitation('inv_UkLWZg9DAJ', 'xK3pQ9vLmT2wRz8N', {
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Robin',
  last_name: 'Ellis',
})

// endregion:example

export { auth }

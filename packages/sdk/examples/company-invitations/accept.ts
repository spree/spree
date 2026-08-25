import { createClient } from '@spree/sdk'

const client = createClient({
  baseUrl: 'https://your-store.com',
  publishableKey: '<api-key>',
})

// region:example
// Unauthenticated: the token from the invite email is the credential, and the
// registration payload creates the account with the invited address.
const membership = await client.companyInvitations.accept('<invitation-token>', {
  first_name: 'Ada',
  password: 'a-strong-password',
  password_confirmation: 'a-strong-password',
})

// endregion:example

export { membership }

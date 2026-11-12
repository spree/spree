import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The note tells the seller what to fix before they submit again.
const seller = await client.sellers.reopenOnboarding('sel_UkLWZg9DAJ', {
  note: 'Please upload a bank statement dated within the last 3 months.',
})

// endregion:example

export { seller }

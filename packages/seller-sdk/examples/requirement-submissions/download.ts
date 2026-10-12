import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
// The onboarding checklist carries each requirement's latest submission.
const { requirements } = await client.onboarding.get()
const submission = requirements.find((requirement) => requirement.submission?.file_url)?.submission

if (submission?.file_url) {
  // Documents are served through the API, so fetch with the session's token
  // and seller, then drive the browser download:
  const response = await fetch(`https://your-store.com${submission.file_url}`, {
    headers: { Authorization: 'Bearer eyJhbGciOi...', 'X-Spree-Seller-Id': 'sel_UkLWZg9DAJ' },
  })
  const url = URL.createObjectURL(await response.blob())
  const link = Object.assign(document.createElement('a'), {
    href: url,
    download: submission.file_name ?? 'document',
  })
  link.click()
  URL.revokeObjectURL(url)
}
// endregion:example

import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const label = await client.orders.fulfillments.labels.get(
  'or_UkLWZg9DAJ',
  'ful_UkLWZg9DAJ',
  'lbl_UkLWZg9DAJ',
)

if (label.download_url) {
  // Labels are served through the API, so fetch with the session's token
  // and seller, then drive the browser download for printing:
  const response = await fetch(`https://your-store.com${label.download_url}`, {
    headers: { Authorization: 'Bearer eyJhbGciOi...', 'X-Spree-Seller-Id': 'sel_UkLWZg9DAJ' },
  })
  if (!response.ok) throw new Error(`Download failed with status ${response.status}`)
  const url = URL.createObjectURL(await response.blob())
  const link = Object.assign(document.createElement('a'), {
    href: url,
    download: `label-${label.tracking_number ?? label.id}.${label.format ?? 'pdf'}`,
  })
  link.click()
  URL.revokeObjectURL(url)
}
// endregion:example

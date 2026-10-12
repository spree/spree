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
  // and seller, then open the file for printing:
  const response = await fetch(`https://your-store.com${label.download_url}`, {
    headers: { Authorization: 'Bearer eyJhbGciOi...', 'X-Spree-Seller-Id': 'sel_UkLWZg9DAJ' },
  })
  const url = URL.createObjectURL(await response.blob())
  window.open(url)
}
// endregion:example

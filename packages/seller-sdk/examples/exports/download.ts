import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

declare const token: string
declare const sellerId: string
const fetched = await client.exports.get('exp_UkLWZg9DAJ')
// `download_url` is set once the export is `done`.
const exp = fetched as { download_url: string; filename: string }

// region:example
// Exports are served through the API, so fetch with the session's token and
// seller, then drive the browser download:
const response = await fetch(`https://your-store.com${exp.download_url}`, {
  headers: { Authorization: `Bearer ${token}`, 'X-Spree-Seller-Id': sellerId },
})
const blob = await response.blob()
const url = URL.createObjectURL(blob)
const link = Object.assign(document.createElement('a'), {
  href: url,
  download: exp.filename,
})
link.click()
URL.revokeObjectURL(url)
// endregion:example

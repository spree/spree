import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
// The PDF is served through the API, so fetch it with the seller's
// credentials, then drive the browser download from a Blob.
const invoice = await client.invoices.get('invc_UkLWZg9DAJ')

if (invoice.download_url) {
  const response = await fetch(`https://your-store.com${invoice.download_url}`, {
    headers: { Authorization: 'Bearer eyJhbGciOi...', 'X-Spree-Seller-Id': 'sel_UkLWZg9DAJ' },
  })
  if (!response.ok) throw new Error(`Download failed: ${response.status}`)

  const url = URL.createObjectURL(await response.blob())
  const link = Object.assign(document.createElement('a'), {
    href: url,
    download: invoice.file_filename ?? invoice.number,
  })
  link.click()
  URL.revokeObjectURL(url)
}
// endregion:example

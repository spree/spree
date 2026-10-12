import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

declare const token: string
declare const sellerId: string
const created = await client.requirementSubmissions.create('selreq_xxx', { note: 'Attached.' })
// A submission carries `file_url` only when a document is attached.
const submission = created as { file_url: string; file_name: string }

// region:example
// Documents are served through the API, so fetch with the session's token and
// seller, then drive the browser download:
const response = await fetch(`https://your-store.com${submission.file_url}`, {
  headers: { Authorization: `Bearer ${token}`, 'X-Spree-Seller-Id': sellerId },
})
const blob = await response.blob()
const url = URL.createObjectURL(blob)
const link = Object.assign(document.createElement('a'), {
  href: url,
  download: submission.file_name,
})
link.click()
URL.revokeObjectURL(url)
// endregion:example

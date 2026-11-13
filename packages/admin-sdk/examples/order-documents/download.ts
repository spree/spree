import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The file is served through the API, so fetch it with the API key,
// then drive the browser download from a Blob.
const { data: documents } = await client.orders.documents.list('or_UkLWZg9DAJ')
const document_ = documents[0]

if (document_?.download_url) {
  const response = await fetch(`https://your-store.com${document_.download_url}`, {
    headers: { 'X-Spree-API-Key': 'sk_xxx' },
  })
  if (!response.ok) throw new Error(`Download failed: ${response.status}`)

  const url = URL.createObjectURL(await response.blob())
  const link = Object.assign(document.createElement('a'), {
    href: url,
    download: document_.file_filename ?? document_.label,
  })
  link.click()
  URL.revokeObjectURL(url)
}
// endregion:example

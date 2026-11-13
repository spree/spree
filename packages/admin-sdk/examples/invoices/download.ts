import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The PDF is served through the API, so fetch it with the API key,
// then drive the browser download from a Blob.
const invoice = await client.invoices.get('inv_UkLWZg9DAJ')

if (invoice.download_url) {
  const response = await fetch(`https://your-store.com${invoice.download_url}`, {
    headers: { 'X-Spree-API-Key': 'sk_xxx' },
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

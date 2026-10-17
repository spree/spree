import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The document is served through the API, so fetch it with the API key,
// then drive the browser download from a Blob.
const certificate = await client.companies.taxExemptionCertificates.get(
  'comp_UkLWZg9DAJ',
  'cert_k5nR8xLqPz',
)

if (certificate.document_url) {
  const response = await fetch(`https://your-store.com${certificate.document_url}`, {
    headers: { 'X-Spree-API-Key': 'sk_xxx' },
  })
  if (!response.ok) throw new Error(`Download failed: ${response.status}`)

  const url = URL.createObjectURL(await response.blob())
  const link = Object.assign(document.createElement('a'), {
    href: url,
    download: certificate.document_filename ?? 'certificate',
  })
  link.click()
  URL.revokeObjectURL(url)
}
// endregion:example

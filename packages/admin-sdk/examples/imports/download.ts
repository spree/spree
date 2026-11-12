import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
const productImport = await client.imports.get('imp_UkLWZg9DAJ')

if (productImport.original_file_url) {
  // The uploaded file is served through the API, so fetch it with the API key:
  const response = await fetch(`https://your-store.com${productImport.original_file_url}`, {
    headers: { 'X-Spree-API-Key': 'sk_xxx' },
  })
  if (!response.ok) throw new Error(`Download failed with status ${response.status}`)
  const csv = await response.text()
  console.log(csv)
}
// endregion:example

import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
const productImport = await client.imports.get('imp_UkLWZg9DAJ')

if (productImport.original_file_url) {
  // The uploaded file is served through the API, so fetch it with the
  // session's token and seller, then drive the browser download:
  const response = await fetch(`https://your-store.com${productImport.original_file_url}`, {
    headers: { Authorization: 'Bearer eyJhbGciOi...', 'X-Spree-Seller-Id': 'sel_UkLWZg9DAJ' },
  })
  if (!response.ok) throw new Error(`Download failed with status ${response.status}`)
  const url = URL.createObjectURL(await response.blob())
  const link = Object.assign(document.createElement('a'), {
    href: url,
    download: productImport.original_filename ?? 'import.csv',
  })
  link.click()
  URL.revokeObjectURL(url)
}
// endregion:example

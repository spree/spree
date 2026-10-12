import { createSellerClient } from '@spree/seller-sdk'

const client = createSellerClient({
  baseUrl: 'https://your-store.com',
  jwtToken: 'eyJhbGciOi...',
  sellerId: 'sel_UkLWZg9DAJ',
})

// region:example
// An export is built in the background; poll until it is done.
let exp = await client.exports.get('exp_UkLWZg9DAJ')
while (!exp.done) {
  await new Promise((resolve) => setTimeout(resolve, 2000))
  exp = await client.exports.get(exp.id)
}

if (exp.download_url) {
  // Exports are served through the API, so fetch with the session's token
  // and seller, then drive the browser download:
  const response = await fetch(`https://your-store.com${exp.download_url}`, {
    headers: { Authorization: 'Bearer eyJhbGciOi...', 'X-Spree-Seller-Id': 'sel_UkLWZg9DAJ' },
  })
  const url = URL.createObjectURL(await response.blob())
  const link = Object.assign(document.createElement('a'), {
    href: url,
    download: exp.filename ?? 'export.csv',
  })
  link.click()
  URL.revokeObjectURL(url)
}
// endregion:example

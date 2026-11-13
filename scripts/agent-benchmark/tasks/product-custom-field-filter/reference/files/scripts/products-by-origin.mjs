#!/usr/bin/env node
// Prints the ids of the products whose specs.origin custom field equals the
// given country, one per line, by filtering through the Admin API.
//
//   SPREE_API_URL=http://localhost:3000 SPREE_SECRET_KEY=sk_... node scripts/products-by-origin.mjs Portugal
const country = process.argv[2]
const { SPREE_API_URL: apiUrl, SPREE_SECRET_KEY: secretKey } = process.env

if (!country || !apiUrl || !secretKey) {
  console.error(
    'Usage: SPREE_API_URL=... SPREE_SECRET_KEY=sk_... node scripts/products-by-origin.mjs <country>',
  )
  process.exit(64)
}

// Accept the store's origin or a URL that already ends in the API path.
const base = `${apiUrl.replace(/\/+$/, '').replace(/\/api(\/v3(\/admin)?)?$/, '')}/api/v3/admin`

for (let page = 1; ; page++) {
  const query = new URLSearchParams({
    'q[cf_specs_origin_eq]': country,
    page: String(page),
    limit: '100',
  })
  const response = await fetch(`${base}/products?${query}`, {
    headers: { 'x-spree-api-key': secretKey },
  })
  if (!response.ok) {
    console.error(`Admin API answered ${response.status}: ${await response.text()}`)
    process.exit(1)
  }
  const { data, meta } = await response.json()
  for (const product of data) console.log(product.id)
  if (!meta?.next) break
}

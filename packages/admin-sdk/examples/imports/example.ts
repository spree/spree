// region:example
// Redirects to a populated example CSV; fetch follows the redirect.
const response = await fetch('https://your-store.com/api/v3/admin/imports/example?type=products', {
  headers: { 'X-Spree-API-Key': 'sk_xxx' },
})
if (!response.ok) throw new Error(`Download failed with status ${response.status}`)
const exampleCsv = await response.text()

// endregion:example

export { exampleCsv }

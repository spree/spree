// region:example
// The template is a CSV, so fetch it directly with the API key:
const response = await fetch('https://your-store.com/api/v3/admin/imports/template?type=products', {
  headers: { 'X-Spree-API-Key': 'sk_xxx' },
})
if (!response.ok) throw new Error(`Download failed with status ${response.status}`)
const csvHeader = await response.text()

// endregion:example

export { csvHeader }

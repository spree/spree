import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

declare const token: string
const _exp = await client.exports.get('exp_xxx')
// The download endpoint only returns a URL once the export is `done`; narrow
// the type for the example so callers don't have to handle the null branch.
const exp = _exp as { download_url: string; filename: string }

// region:example
// Fetch with the Bearer token, then drive the browser download:
const res = await fetch(exp.download_url, {
  headers: { Authorization: `Bearer ${token}` }
})
const blob = await res.blob()
const url = URL.createObjectURL(blob)
const a = Object.assign(document.createElement('a'), {
  href: url,
  download: exp.filename
})
a.click()
URL.revokeObjectURL(url)
// endregion:example

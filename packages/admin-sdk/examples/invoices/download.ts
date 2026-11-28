import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The PDF is served through the API with the secret key, which must never
// reach a browser. Pass it on from a route on your own server instead.
export async function GET(): Promise<Response> {
  const invoice = await client.invoices.get('invc_UkLWZg9DAJ')
  if (!invoice.download_url) return new Response(null, { status: 404 })

  const file = await fetch(`https://your-store.com${invoice.download_url}`, {
    headers: { 'X-Spree-API-Key': 'sk_xxx' },
  })
  if (!file.ok) return new Response(null, { status: file.status })

  return new Response(file.body, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="${invoice.file_filename ?? `${invoice.number}.pdf`}"`,
    },
  })
}
// endregion:example

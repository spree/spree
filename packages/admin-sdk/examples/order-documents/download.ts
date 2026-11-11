import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// The file is served through the API with the secret key, which must never
// reach a browser. Pass it on from a route on your own server instead.
export async function GET(): Promise<Response> {
  const { data: documents } = await client.orders.documents.list('or_UkLWZg9DAJ')
  const document_ = documents[0]
  if (!document_?.download_url) return new Response(null, { status: 404 })

  const file = await fetch(`https://your-store.com${document_.download_url}`, {
    headers: { 'X-Spree-API-Key': 'sk_xxx' },
  })
  if (!file.ok) return new Response(null, { status: file.status })

  return new Response(file.body, {
    headers: {
      'Content-Type': file.headers.get('Content-Type') ?? 'application/octet-stream',
      'Content-Disposition': `attachment; filename="${document_.file_filename ?? document_.label}"`,
    },
  })
}
// endregion:example

import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

declare const certificatePdf: Blob // the certificate PDF, e.g. from a file input or `fs.openAsBlob()`

// region:example
// Upload the document first, then pass the signed id.
const { signed_id } = await client.files.upload(certificatePdf, { visibility: 'private' })

const certificate = await client.companies.taxExemptionCertificates.create('comp_UkLWZg9DAJ', {
  certificate_number: 'DE-RESALE-7',
  reason_code: 'resale',
  country_code: 'DE',
  document_signed_id: signed_id,
})

// endregion:example

export { certificate }

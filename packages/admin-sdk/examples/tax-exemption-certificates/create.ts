import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

declare const certificatePdf: Blob // the certificate PDF, e.g. from a file input or `fs.openAsBlob()`

const { signed_id } = await client.files.upload(certificatePdf, { visibility: 'private' })

// region:example
// `signed_id` comes from `client.files.upload(file, { visibility: 'private' })`.
const certificate = await client.companies.taxExemptionCertificates.create('comp_UkLWZg9DAJ', {
  certificate_number: 'DE-RESALE-7',
  reason_code: 'resale',
  country_code: 'DE',
  document_signed_id: signed_id,
})

// endregion:example

export { certificate }

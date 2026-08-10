import { createAdminClient } from '@spree/admin-sdk'

const client = createAdminClient({
  baseUrl: 'https://your-store.com',
  secretKey: 'sk_xxx',
})

// region:example
// Upload the document first, then pass the signed id.
const { signed_id } = await client.directUploads.create({
  blob: {
    filename: 'resale.pdf',
    byte_size: 18_345,
    checksum: 'Base64EncodedMD5==',
    content_type: 'application/pdf',
  },
})

const certificate = await client.companies.taxExemptionCertificates.create('comp_UkLWZg9DAJ', {
  certificate_number: 'DE-RESALE-7',
  reason_code: 'resale',
  country_iso: 'DE',
  document: signed_id,
})

// endregion:example

export { certificate }

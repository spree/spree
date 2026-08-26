import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleCompany = {
  id: 'comp_abc123',
  name: 'Acme Industrial',
  external_references: { erp: 'ACME-1' },
  kind: 'company',
  parent_id: null,
  ancestors: [],
  children_count: 1,
  members_count: 2,
  metadata: {},
  created_at: '2026-08-01T00:00:00Z',
  updated_at: '2026-08-01T00:00:00Z',
}

const sampleAddress = {
  id: 'caddr_abc123',
  company_id: 'comp_abc123',
  label: 'HQ',
  default_billing: true,
  default_shipping: false,
  address: null,
  created_at: '2026-08-01T00:00:00Z',
  updated_at: '2026-08-01T00:00:00Z',
}

const sampleCertificate = {
  id: 'cert_abc123',
  company_id: 'comp_abc123',
  certificate_number: 'DE-RESALE-1',
  reason_code: 'resale',
  status: 'pending',
  country_code: 'DE',
  state_code: null,
  active: false,
  lapsed: false,
  can_be_deleted: true,
  document_filename: null,
  document_byte_size: null,
  document_url: null,
  metadata: {},
  created_at: '2026-08-01T00:00:00Z',
  updated_at: '2026-08-01T00:00:00Z',
}

describe('companies', () => {
  it('lists companies and wraps Ransack predicates', async () => {
    let url: URL | null = null
    server.use(
      http.get(`${API_PREFIX}/companies`, ({ request }) => {
        url = new URL(request.url)
        return HttpResponse.json(paginated([sampleCompany]))
      }),
    )

    const res = await createTestClient().companies.list({ name_cont: 'Acme' })

    expect(res.data[0]?.id).toBe('comp_abc123')
    expect(url!.searchParams.get('q[name_cont]')).toBe('Acme')
  })

  it('creates, updates and deletes a company', async () => {
    let created: Record<string, unknown> | null = null
    let patched: Record<string, unknown> | null = null
    let deleted = false
    server.use(
      http.post(`${API_PREFIX}/companies`, async ({ request }) => {
        created = (await request.json()) as Record<string, unknown>
        return HttpResponse.json(sampleCompany, { status: 201 })
      }),
      http.patch(`${API_PREFIX}/companies/comp_abc123`, async ({ request }) => {
        patched = (await request.json()) as Record<string, unknown>
        return HttpResponse.json(sampleCompany)
      }),
      http.delete(`${API_PREFIX}/companies/comp_abc123`, () => {
        deleted = true
        return new HttpResponse(null, { status: 204 })
      }),
    )

    const client = createTestClient()
    await client.companies.create({
      name: 'Globex Corporation',
      external_references: { erp: 'GLBX' },
    })
    await client.companies.update('comp_abc123', { name: 'Acme Global' })
    await client.companies.delete('comp_abc123')

    expect(created).toEqual({
      name: 'Globex Corporation',
      external_references: { erp: 'GLBX' },
    })
    expect(patched).toEqual({ name: 'Acme Global' })
    expect(deleted).toBe(true)
  })

  describe('addresses', () => {
    it('lists and creates under the node, edits and deletes by its own id', async () => {
      let body: Record<string, unknown> | null = null
      let patched: Record<string, unknown> | null = null
      server.use(
        http.get(`${API_PREFIX}/companies/comp_abc123/addresses`, () =>
          HttpResponse.json(paginated([sampleAddress])),
        ),
        http.post(`${API_PREFIX}/companies/comp_abc123/addresses`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleAddress, { status: 201 })
        }),
        http.patch(
          `${API_PREFIX}/companies/comp_abc123/addresses/caddr_abc123`,
          async ({ request }) => {
            patched = (await request.json()) as Record<string, unknown>
            return HttpResponse.json(sampleAddress)
          },
        ),
        http.delete(
          `${API_PREFIX}/companies/comp_abc123/addresses/caddr_abc123`,
          () => new HttpResponse(null, { status: 204 }),
        ),
      )

      const client = createTestClient()
      const listed = await client.companies.addresses.list('comp_abc123')
      await client.companies.addresses.create('comp_abc123', {
        label: 'Plant 2 dock',
        default_shipping: true,
        city: 'Hamburg',
        country_code: 'DE',
      })
      await client.companies.addresses.update('comp_abc123', 'caddr_abc123', { city: 'Berlin' })
      await expect(
        client.companies.addresses.delete('comp_abc123', 'caddr_abc123'),
      ).resolves.toBeUndefined()

      expect(listed.data[0]?.id).toBe('caddr_abc123')
      expect(body).toEqual({
        label: 'Plant 2 dock',
        default_shipping: true,
        city: 'Hamburg',
        country_code: 'DE',
      })
      expect(patched).toEqual({ city: 'Berlin' })
    })
  })

  describe('memberships', () => {
    // Adding by email does the right thing server-side: a membership for an
    // existing customer, an invitation otherwise.
    it('adds a member by email and removes standing by membership id', async () => {
      let body: Record<string, unknown> | null = null
      const membership = {
        id: 'cmem_abc123',
        company_id: 'comp_abc123',
        customer_id: 'cus_1',
        role: 'buyer',
        email: 'buyer@acme.test',
        created_at: '',
        updated_at: '',
      }
      server.use(
        http.get(`${API_PREFIX}/companies/comp_abc123/memberships`, () =>
          HttpResponse.json(paginated([membership])),
        ),
        http.post(`${API_PREFIX}/companies/comp_abc123/memberships`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(membership, { status: 201 })
        }),
        http.delete(
          `${API_PREFIX}/companies/comp_abc123/memberships/cmem_abc123`,
          () => new HttpResponse(null, { status: 204 }),
        ),
      )

      const client = createTestClient()
      const listed = await client.companies.memberships.list('comp_abc123')
      await client.companies.memberships.create('comp_abc123', {
        customer_email: 'buyer@acme.test',
      })
      await expect(
        client.companies.memberships.delete('comp_abc123', 'cmem_abc123'),
      ).resolves.toBeUndefined()

      expect(listed.data[0]?.email).toBe('buyer@acme.test')
      expect(body).toEqual({ customer_email: 'buyer@acme.test' })
    })
  })

  describe('invitations', () => {
    it('lists pending invitations and revokes by id', async () => {
      const invitation = {
        id: 'cinv_abc123',
        company_id: 'comp_abc123',
        email: 'new@acme.test',
        status: 'pending',
        expires_at: '2026-09-01T00:00:00Z',
        accepted_at: null,
        revoked_at: null,
        created_at: '',
        updated_at: '',
      }
      server.use(
        http.get(`${API_PREFIX}/companies/comp_abc123/invitations`, () =>
          HttpResponse.json(paginated([invitation])),
        ),
        http.delete(
          `${API_PREFIX}/companies/comp_abc123/invitations/cinv_abc123`,
          () => new HttpResponse(null, { status: 204 }),
        ),
      )

      const client = createTestClient()
      const listed = await client.companies.invitations.list('comp_abc123')
      await expect(
        client.companies.invitations.delete('comp_abc123', 'cinv_abc123'),
      ).resolves.toBeUndefined()

      expect(listed.data[0]?.status).toBe('pending')
    })
  })

  describe('taxIdentifiers', () => {
    it('registers a number and re-checks it', async () => {
      let body: Record<string, unknown> | null = null
      let validated = false
      const identifier = {
        id: 'txi_abc123',
        kind: 'eu_vat',
        value: 'DE123456789',
        validation_status: null,
        created_at: '',
        updated_at: '',
      }
      server.use(
        http.post(`${API_PREFIX}/companies/comp_abc123/tax_identifiers`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(identifier, { status: 201 })
        }),
        http.post(`${API_PREFIX}/companies/comp_abc123/tax_identifiers/txi_abc123/validate`, () => {
          validated = true
          return HttpResponse.json({ ...identifier, validation_status: 'pending' }, { status: 202 })
        }),
      )

      const client = createTestClient()
      await client.companies.taxIdentifiers.create('comp_abc123', {
        kind: 'eu_vat',
        value: 'DE123456789',
      })
      const rechecked = await client.companies.taxIdentifiers.validate('comp_abc123', 'txi_abc123')

      expect(body).toEqual({ kind: 'eu_vat', value: 'DE123456789' })
      expect(validated).toBe(true)
      expect(rechecked.validation_status).toBe('pending')
    })
  })

  describe('taxExemptionCertificates', () => {
    it('creates with a signed document id', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(
          `${API_PREFIX}/companies/comp_abc123/tax_exemption_certificates`,
          async ({ request }) => {
            body = (await request.json()) as Record<string, unknown>
            return HttpResponse.json(sampleCertificate, { status: 201 })
          },
        ),
      )

      await createTestClient().companies.taxExemptionCertificates.create('comp_abc123', {
        certificate_number: 'DE-RESALE-7',
        reason_code: 'resale',
        document: 'signed-blob-id',
      })

      expect(body).toEqual({
        certificate_number: 'DE-RESALE-7',
        reason_code: 'resale',
        document: 'signed-blob-id',
      })
    })

    // Accepting and withdrawing are their own actions, never mass assignment.
    it('verifies and revokes through member actions', async () => {
      server.use(
        http.patch(
          `${API_PREFIX}/companies/comp_abc123/tax_exemption_certificates/cert_abc123/verify`,
          () => HttpResponse.json({ ...sampleCertificate, status: 'verified', active: true }),
        ),
        http.patch(
          `${API_PREFIX}/companies/comp_abc123/tax_exemption_certificates/cert_abc123/revoke`,
          () => HttpResponse.json({ ...sampleCertificate, status: 'revoked' }),
        ),
      )

      const client = createTestClient()
      const verified = await client.companies.taxExemptionCertificates.verify(
        'comp_abc123',
        'cert_abc123',
      )
      const revoked = await client.companies.taxExemptionCertificates.revoke(
        'comp_abc123',
        'cert_abc123',
      )

      expect(verified.status).toBe('verified')
      expect(verified.active).toBe(true)
      expect(revoked.status).toBe('revoked')
    })
  })
})

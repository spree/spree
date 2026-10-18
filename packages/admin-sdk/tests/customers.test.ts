import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleCustomer = {
  id: 'cus_abc123',
  email: 'jane@example.com',
  first_name: 'Jane',
  last_name: 'Doe',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

const sampleCreditCard = { id: 'cc_1', brand: 'visa', last4: '4242' }
const sampleAddress = { id: 'addr_1', first_name: 'Jane', city: 'Berlin' }
const sampleStoreCredit = { id: 'sc_1', amount: '50.0', currency: 'USD' }

describe('customers', () => {
  describe('list', () => {
    it('GETs /customers and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/customers`, () => HttpResponse.json(paginated([sampleCustomer]))),
      )

      const res = await createTestClient().customers.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('cus_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/customers`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().customers.list({ email_cont: 'jane', first_name_eq: 'Jane' })

      expect(url!.searchParams.get('q[email_cont]')).toBe('jane')
      expect(url!.searchParams.get('q[first_name_eq]')).toBe('Jane')
    })
  })

  describe('get', () => {
    it('GETs /customers/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/customers/cus_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleCustomer)
        }),
      )

      const res = await createTestClient().customers.get('cus_abc123', { expand: ['addresses'] })

      expect(res.id).toBe('cus_abc123')
      expect(url!.searchParams.get('expand')).toBe('addresses')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/customers`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleCustomer, { status: 201 })
        }),
      )

      await createTestClient().customers.create({ email: 'jane@example.com', first_name: 'Jane' })

      expect(body).toEqual({ email: 'jane@example.com', first_name: 'Jane' })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/customers/cus_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleCustomer, last_name: 'Smith' })
        }),
      )

      const res = await createTestClient().customers.update('cus_abc123', { last_name: 'Smith' })

      expect(body).toEqual({ last_name: 'Smith' })
      expect(res.last_name).toBe('Smith')
    })

    it('DELETEs /customers/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/customers/cus_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().customers.delete('cus_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })

  describe('bulk operations', () => {
    it('POSTs /bulk_add_to_groups with ids + customer_group_ids', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/customers/bulk_add_to_groups`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ customer_count: 2, customer_group_count: 1 })
        }),
      )

      const res = await createTestClient().customers.bulkAddToGroups({
        ids: ['cus_a', 'cus_b'],
        customer_group_ids: ['cg_1'],
      })

      expect(body).toEqual({ ids: ['cus_a', 'cus_b'], customer_group_ids: ['cg_1'] })
      expect(res.customer_count).toBe(2)
    })

    it('POSTs /bulk_add_tags with ids + tags', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/customers/bulk_add_tags`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ customer_count: 1, tag_count: 2 })
        }),
      )

      await createTestClient().customers.bulkAddTags({ ids: ['cus_a'], tags: ['vip', 'eu'] })

      expect(body).toEqual({ ids: ['cus_a'], tags: ['vip', 'eu'] })
    })
  })

  describe('nested credit cards', () => {
    it('GETs /customers/:id/credit_cards', async () => {
      server.use(
        http.get(`${API_PREFIX}/customers/cus_abc123/credit_cards`, () =>
          HttpResponse.json(paginated([sampleCreditCard])),
        ),
      )

      const res = await createTestClient().customers.creditCards.list('cus_abc123')

      expect(res.data[0]?.id).toBe('cc_1')
    })

    it('DELETEs a customer credit card', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/customers/cus_abc123/credit_cards/cc_1`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await createTestClient().customers.creditCards.delete('cus_abc123', 'cc_1')
      expect(hit).toBe(true)
    })
  })

  describe('nested addresses', () => {
    it('POSTs a new address under the customer', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/customers/cus_abc123/addresses`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleAddress, { status: 201 })
        }),
      )

      await createTestClient().customers.addresses.create('cus_abc123', {
        first_name: 'Jane',
        city: 'Berlin',
      })

      expect(body).toEqual({ first_name: 'Jane', city: 'Berlin' })
    })

    it('PATCHes an existing customer address by id', async () => {
      let url: string | null = null
      server.use(
        http.patch(`${API_PREFIX}/customers/cus_abc123/addresses/addr_1`, ({ request }) => {
          url = request.url
          return HttpResponse.json(sampleAddress)
        }),
      )

      await createTestClient().customers.addresses.update('cus_abc123', 'addr_1', {
        city: 'Munich',
      })

      expect(url).toContain('/customers/cus_abc123/addresses/addr_1')
    })
  })

  describe('nested store credits', () => {
    it('POSTs a store credit under the customer', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/customers/cus_abc123/store_credits`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleStoreCredit, { status: 201 })
        }),
      )

      await createTestClient().customers.storeCredits.create('cus_abc123', {
        amount: 50,
        currency: 'USD',
        category_id: 'scc_1',
      })

      expect(body).toEqual({ amount: 50, currency: 'USD', category_id: 'scc_1' })
    })
  })
})

describe('consentRecords', () => {
  it('GETs /consent_records with Ransack-wrapped filters', async () => {
    let url: URL | null = null
    server.use(
      http.get(`${API_PREFIX}/consent_records`, ({ request }) => {
        url = new URL(request.url)
        return HttpResponse.json(paginated([{ id: 'consent_1', purpose: 'marketing' }]))
      }),
    )

    const res = await createTestClient().consentRecords.list({ email_eq: 'jane@example.com' })

    expect(res.data[0]?.id).toBe('consent_1')
    expect(url!.searchParams.get('q[email_eq]')).toBe('jane@example.com')
  })
})

describe('dataRequests', () => {
  it('GETs /data_requests', async () => {
    server.use(
      http.get(`${API_PREFIX}/data_requests`, () =>
        HttpResponse.json(paginated([{ id: 'dsr_1', kind: 'erasure' }])),
      ),
    )

    const res = await createTestClient().dataRequests.list()

    expect(res.data[0]?.kind).toBe('erasure')
  })

  it('POSTs /data_requests with the customer and kind', async () => {
    let body: unknown = null
    server.use(
      http.post(`${API_PREFIX}/data_requests`, async ({ request }) => {
        body = await request.json()
        return HttpResponse.json({ id: 'dsr_1', kind: 'access' }, { status: 202 })
      }),
    )

    const res = await createTestClient().dataRequests.create({
      customer_id: 'cus_abc123',
      kind: 'access',
    })

    expect(body).toEqual({ customer_id: 'cus_abc123', kind: 'access' })
    expect(res.id).toBe('dsr_1')
  })
})

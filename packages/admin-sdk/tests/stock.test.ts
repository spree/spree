import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleStockLocation = {
  id: 'sl_abc123',
  name: 'Main Warehouse',
  default: true,
  active: true,
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

const sampleStockItem = {
  id: 'si_abc123',
  count_on_hand: 42,
  backorderable: false,
  variant_id: 'variant_1',
  stock_location_id: 'sl_abc123',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

const sampleStockTransfer = {
  id: 'st_abc123',
  number: 'T123456789',
  source_location_id: 'sl_abc123',
  destination_location_id: 'sl_def456',
  created_at: '2026-05-01T00:00:00Z',
  updated_at: '2026-05-01T00:00:00Z',
}

describe('stockLocations', () => {
  describe('list', () => {
    it('GETs /stock_locations and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/stock_locations`, () =>
          HttpResponse.json(paginated([sampleStockLocation])),
        ),
      )

      const res = await createTestClient().stockLocations.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('sl_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/stock_locations`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().stockLocations.list({ name_cont: 'warehouse', active_eq: true })

      expect(url!.searchParams.get('q[name_cont]')).toBe('warehouse')
      expect(url!.searchParams.get('q[active_eq]')).toBe('true')
    })
  })

  describe('get', () => {
    it('GETs /stock_locations/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/stock_locations/sl_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleStockLocation)
        }),
      )

      const res = await createTestClient().stockLocations.get('sl_abc123', {
        expand: ['stock_items'],
      })

      expect(res.id).toBe('sl_abc123')
      expect(url!.searchParams.get('expand')).toBe('stock_items')
    })
  })

  describe('create / update / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/stock_locations`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleStockLocation, { status: 201 })
        }),
      )

      await createTestClient().stockLocations.create({ name: 'Main Warehouse', default: true })

      expect(body).toEqual({ name: 'Main Warehouse', default: true })
    })

    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/stock_locations/sl_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleStockLocation, active: false })
        }),
      )

      const res = await createTestClient().stockLocations.update('sl_abc123', { active: false })

      expect(body).toEqual({ active: false })
      expect(res.active).toBe(false)
    })

    it('DELETEs /stock_locations/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/stock_locations/sl_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().stockLocations.delete('sl_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})

describe('stockItems', () => {
  describe('list', () => {
    it('GETs /stock_items and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/stock_items`, () =>
          HttpResponse.json(paginated([sampleStockItem])),
        ),
      )

      const res = await createTestClient().stockItems.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('si_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/stock_items`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().stockItems.list({
        stock_location_id_eq: 'sl_abc123',
        variant_id_eq: 'variant_1',
      })

      expect(url!.searchParams.get('q[stock_location_id_eq]')).toBe('sl_abc123')
      expect(url!.searchParams.get('q[variant_id_eq]')).toBe('variant_1')
    })
  })

  describe('get', () => {
    it('GETs /stock_items/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/stock_items/si_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleStockItem)
        }),
      )

      const res = await createTestClient().stockItems.get('si_abc123', { expand: ['variant'] })

      expect(res.id).toBe('si_abc123')
      expect(url!.searchParams.get('expand')).toBe('variant')
    })
  })

  describe('update / delete', () => {
    it('PATCHes the update body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.patch(`${API_PREFIX}/stock_items/si_abc123`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json({ ...sampleStockItem, count_on_hand: 100 })
        }),
      )

      const res = await createTestClient().stockItems.update('si_abc123', { count_on_hand: 100 })

      expect(body).toEqual({ count_on_hand: 100 })
      expect(res.count_on_hand).toBe(100)
    })

    it('DELETEs /stock_items/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/stock_items/si_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().stockItems.delete('si_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})

describe('stockTransfers', () => {
  describe('list', () => {
    it('GETs /stock_transfers and returns paginated data', async () => {
      server.use(
        http.get(`${API_PREFIX}/stock_transfers`, () =>
          HttpResponse.json(paginated([sampleStockTransfer])),
        ),
      )

      const res = await createTestClient().stockTransfers.list()

      expect(res.data).toHaveLength(1)
      expect(res.data[0]?.id).toBe('st_abc123')
    })

    it('wraps Ransack predicates via transformListParams', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/stock_transfers`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(paginated([]))
        }),
      )

      await createTestClient().stockTransfers.list({
        number_cont: 'T123',
        source_location_id_eq: 'sl_abc123',
      })

      expect(url!.searchParams.get('q[number_cont]')).toBe('T123')
      expect(url!.searchParams.get('q[source_location_id_eq]')).toBe('sl_abc123')
    })
  })

  describe('get', () => {
    it('GETs /stock_transfers/:id and forwards expand params', async () => {
      let url: URL | null = null
      server.use(
        http.get(`${API_PREFIX}/stock_transfers/st_abc123`, ({ request }) => {
          url = new URL(request.url)
          return HttpResponse.json(sampleStockTransfer)
        }),
      )

      const res = await createTestClient().stockTransfers.get('st_abc123', {
        expand: ['stock_movements'],
      })

      expect(res.id).toBe('st_abc123')
      expect(url!.searchParams.get('expand')).toBe('stock_movements')
    })
  })

  describe('create / delete', () => {
    it('POSTs the create body verbatim', async () => {
      let body: Record<string, unknown> | null = null
      server.use(
        http.post(`${API_PREFIX}/stock_transfers`, async ({ request }) => {
          body = (await request.json()) as Record<string, unknown>
          return HttpResponse.json(sampleStockTransfer, { status: 201 })
        }),
      )

      await createTestClient().stockTransfers.create({
        source_location_id: 'sl_abc123',
        destination_location_id: 'sl_def456',
      })

      expect(body).toEqual({
        source_location_id: 'sl_abc123',
        destination_location_id: 'sl_def456',
      })
    })

    it('DELETEs /stock_transfers/:id', async () => {
      let hit = false
      server.use(
        http.delete(`${API_PREFIX}/stock_transfers/st_abc123`, () => {
          hit = true
          return new HttpResponse(null, { status: 204 })
        }),
      )

      await expect(createTestClient().stockTransfers.delete('st_abc123')).resolves.toBeUndefined()
      expect(hit).toBe(true)
    })
  })
})

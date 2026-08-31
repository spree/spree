import { HttpResponse, http } from 'msw'
import { describe, expect, it } from 'vitest'
import { API_PREFIX, createTestClient, paginated } from './helpers'
import { server } from './mocks/server'

const sampleCatalog = {
  id: 'cat_abc123',
  name: 'Wholesale',
  active: true,
  position: 1,
  price_list_id: null,
  products_count: 0,
  metadata: {},
  created_at: '2026-08-01T00:00:00Z',
  updated_at: '2026-08-01T00:00:00Z',
}

describe('catalogs', () => {
  it('lists catalogs and wraps Ransack predicates', async () => {
    let url: URL | null = null
    server.use(
      http.get(`${API_PREFIX}/catalogs`, ({ request }) => {
        url = new URL(request.url)
        return HttpResponse.json(paginated([sampleCatalog]))
      }),
    )

    const res = await createTestClient().catalogs.list({ name_cont: 'Whole' })

    expect(res.data[0]?.id).toBe('cat_abc123')
    expect(url!.searchParams.get('q[name_cont]')).toBe('Whole')
  })

  it('manages the assortment through the nested products resource', async () => {
    let added: Record<string, unknown> | null = null
    let removed: Record<string, unknown> | null = null
    server.use(
      http.post(`${API_PREFIX}/catalogs/cat_abc123/products`, async ({ request }) => {
        added = (await request.json()) as Record<string, unknown>
        return HttpResponse.json({ added_count: 2 }, { status: 201 })
      }),
      // Removal is bulk too — one DELETE carries every id in the body.
      http.delete(`${API_PREFIX}/catalogs/cat_abc123/products`, async ({ request }) => {
        removed = (await request.json()) as Record<string, unknown>
        return HttpResponse.json({ removed_count: 2 })
      }),
    )

    const client = createTestClient()
    const result = await client.catalogs.products.create('cat_abc123', ['prod_1', 'prod_2'])
    const removal = await client.catalogs.products.delete('cat_abc123', ['prod_1', 'prod_2'])

    expect(result.added_count).toBe(2)
    expect(added).toEqual({ product_ids: ['prod_1', 'prod_2'] })
    expect(removal.removed_count).toBe(2)
    expect(removed).toEqual({ product_ids: ['prod_1', 'prod_2'] })
  })

  it('imports the price list products into the assortment', async () => {
    let imported = false
    server.use(
      http.post(`${API_PREFIX}/catalogs/cat_abc123/import_products`, () => {
        imported = true
        return HttpResponse.json({ added_count: 12 })
      }),
    )

    const result = await createTestClient().catalogs.importProducts('cat_abc123')

    expect(imported).toBe(true)
    expect(result.added_count).toBe(12)
  })

  it('assigns the catalog to an audience and withdraws it', async () => {
    let assigned: Record<string, unknown> | null = null
    let unassigned = false
    server.use(
      http.post(`${API_PREFIX}/catalogs/cat_abc123/assign`, async ({ request }) => {
        assigned = (await request.json()) as Record<string, unknown>
        return HttpResponse.json(
          {
            id: 'cata_1',
            catalog_id: 'cat_abc123',
            assignable_type: 'company',
            assignable_id: 'comp_1',
            assignable_name: 'Acme',
            created_at: '',
          },
          { status: 201 },
        )
      }),
      http.delete(`${API_PREFIX}/catalog_assignments/cata_1`, () => {
        unassigned = true
        return new HttpResponse(null, { status: 204 })
      }),
    )

    const client = createTestClient()
    const assignment = await client.catalogs.assign('cat_abc123', {
      assignable_type: 'company',
      assignable_id: 'comp_1',
    })
    await client.catalogAssignments.delete('cata_1')

    expect(assignment.assignable_type).toBe('company')
    expect(assigned).toEqual({ assignable_type: 'company', assignable_id: 'comp_1' })
    expect(unassigned).toBe(true)
  })
})

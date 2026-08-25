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
    let repositioned: Record<string, unknown> | null = null
    let removed = false
    server.use(
      http.post(`${API_PREFIX}/catalogs/cat_abc123/products`, async ({ request }) => {
        added = (await request.json()) as Record<string, unknown>
        return HttpResponse.json({ added_count: 2 }, { status: 201 })
      }),
      http.delete(`${API_PREFIX}/catalogs/cat_abc123/products/prod_1`, () => {
        removed = true
        return new HttpResponse(null, { status: 204 })
      }),
      http.patch(
        `${API_PREFIX}/catalogs/cat_abc123/products/prod_1/reposition`,
        async ({ request }) => {
          repositioned = (await request.json()) as Record<string, unknown>
          return new HttpResponse(null, { status: 204 })
        },
      ),
    )

    const client = createTestClient()
    const result = await client.catalogs.products.create('cat_abc123', ['prod_1', 'prod_2'])
    await client.catalogs.products.delete('cat_abc123', 'prod_1')
    await client.catalogs.products.reposition('cat_abc123', 'prod_1', 0)

    expect(result.added_count).toBe(2)
    expect(added).toEqual({ product_ids: ['prod_1', 'prod_2'] })
    expect(removed).toBe(true)
    expect(repositioned).toEqual({ new_position: 0 })
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

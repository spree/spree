import { describe, expect, it } from 'vitest'
import {
  type AdminSpec,
  getSchema,
  listEndpoints,
  loadBundledSpec,
  requiredScope,
  resolveRefs,
} from '../src/api/spec'

const fixture: AdminSpec = {
  info: { title: 'Admin API', version: 'v3' },
  paths: {
    '/api/v3/admin/orders': {
      get: {
        summary: 'List orders',
        description:
          'Returns orders.\n\n**Required scope:** `read_orders` (for API-key authentication).',
      },
      post: {
        summary: 'Create order',
        description: '**Required scope:** `write_orders` (for API-key authentication).',
        requestBody: {
          content: {
            'application/json': { schema: { $ref: '#/components/schemas/order_params' } },
          },
        },
      },
    },
    '/api/v3/admin/orders/{id}': {
      get: {
        summary: 'Get order',
        description: '**Required scope:** `read_orders` (for API-key authentication).',
      },
    },
    '/api/v3/admin/exports': {
      post: {
        summary: 'Create export',
        description:
          '**Required scope:** the read scope of the exported resource — `read_products` for product exports, `read_customers` for customer exports, etc. (for API-key authentication).',
      },
    },
    '/api/v3/admin/payment_methods/{id}': {
      get: {
        summary: 'Get payment method',
        description: '**Required scope:** `read_settings` (for API-key authentication).',
      },
    },
    '/api/v3/admin/payment_methods/types': {
      get: {
        summary: 'List payment method types',
        description: '**Required scope:** `read_settings` (for API-key authentication).',
      },
    },
  },
  components: {
    schemas: {
      order_params: {
        type: 'object',
        properties: {
          number: { type: 'string' },
          nested: { $ref: '#/components/schemas/order_params' },
        },
      },
    },
  },
}

describe('requiredScope', () => {
  it('extracts the scope token from the description', () => {
    expect(requiredScope(fixture.paths['/api/v3/admin/orders'].get)).toBe('read_orders')
  })

  it('passes free-form scope notes through (exports)', () => {
    expect(requiredScope(fixture.paths['/api/v3/admin/exports'].post)).toContain(
      'read scope of the exported resource',
    )
  })

  it('returns a dash when no scope line exists', () => {
    expect(requiredScope({ summary: 'x' })).toBe('—')
  })
})

describe('listEndpoints', () => {
  it('lists every operation with method, short path, and scope', () => {
    const rows = listEndpoints(fixture)
    expect(rows).toHaveLength(6)
    expect(rows[0]).toEqual({
      method: 'GET',
      path: '/orders',
      scope: 'read_orders',
      summary: 'List orders',
    })
  })

  it('filters by resource (first path segment)', () => {
    const rows = listEndpoints(fixture, { resource: 'exports' })
    expect(rows).toHaveLength(1)
    expect(rows[0].path).toBe('/exports')
  })

  it('filters by search term across method, path, and summary', () => {
    const rows = listEndpoints(fixture, { search: 'create order' })
    expect(rows).toHaveLength(1)
    expect(rows[0].method).toBe('POST')
  })
})

describe('getSchema', () => {
  it('matches METHOD /path and resolves $refs inline', () => {
    const matches = getSchema(fixture, 'POST /orders')
    expect(matches).toHaveLength(1)
    const body = JSON.stringify(matches[0].requestBody)
    expect(body).toContain('"number"')
  })

  it('keeps cyclic refs as raw pointers instead of recursing forever', () => {
    const matches = getSchema(fixture, 'POST /orders')
    expect(JSON.stringify(matches[0].requestBody)).toContain('#/components/schemas/order_params')
  })

  it('matches a concrete ID against {id} placeholders', () => {
    const matches = getSchema(fixture, 'GET /orders/ord_x8k2J9aQ')
    expect(matches).toHaveLength(1)
    expect(matches[0].path).toBe('/orders/{id}')
  })

  it('returns all methods when no method is given', () => {
    const matches = getSchema(fixture, '/orders')
    expect(matches.map((m) => m.method).sort()).toEqual(['GET', 'POST'])
  })

  it('tolerates the /api/v3/admin prefix in the target', () => {
    expect(getSchema(fixture, 'GET /api/v3/admin/orders')).toHaveLength(1)
  })

  it('prefers an exact literal path over a {id} template (router precedence)', () => {
    const matches = getSchema(fixture, 'GET /payment_methods/types')
    expect(matches).toHaveLength(1)
    expect(matches[0].path).toBe('/payment_methods/types')
    expect(matches[0].summary).toBe('List payment method types')
  })
})

describe('resolveRefs', () => {
  it('returns scalars untouched', () => {
    expect(resolveRefs('x', fixture)).toBe('x')
  })
})

describe('bundled snapshot', () => {
  it('loads with a substantial operation inventory', () => {
    const spec = loadBundledSpec()
    const rows = listEndpoints(spec)
    expect(rows.length).toBeGreaterThan(150)
  })

  it('answers a real schema lookup', () => {
    const matches = getSchema(loadBundledSpec(), 'GET /products')
    expect(matches.length).toBeGreaterThanOrEqual(1)
    expect(matches[0].summary).toBeTruthy()
  })

  it('carries scope annotations for most operations', () => {
    const rows = listEndpoints(loadBundledSpec())
    const annotated = rows.filter((row) => row.scope !== '—')
    expect(annotated.length / rows.length).toBeGreaterThan(0.8)
  })
})

import { HttpResponse, http } from 'msw'

const BASE_URL = 'https://demo.spreecommerce.org'
const API_PREFIX = `${BASE_URL}/api/v3/admin`

export const fixtures = {
  customField: {
    id: 'cf_1',
    label: 'Fabric',
    type: 'Spree::Metafields::ShortText',
    field_type: 'short_text',
    key: 'specs.fabric',
    value: 'wool',
    created_at: '2026-05-01T00:00:00.000Z',
    updated_at: '2026-05-01T00:00:00.000Z',
    storefront_visible: true,
    custom_field_definition_id: 'cfdef_1',
  },
  customFieldDefinition: {
    id: 'cfdef_1',
    namespace: 'specs',
    key: 'fabric',
    resource_type: 'Spree::Product',
    label: 'Fabric',
    field_type: 'short_text',
    storefront_visible: true,
    created_at: '2026-05-01T00:00:00.000Z',
    updated_at: '2026-05-01T00:00:00.000Z',
  },
}

const PARENT_PATHS = [
  'products',
  'variants',
  'orders',
  'customers',
  'categories',
  'option_types',
] as const

// Echo the matched route segment + parent ID into the response under `_route`
// so SDK routing tests can assert on which path actually fired. Without this,
// every parent returned the same fixture and a wiring bug would slip through.
const echoRoute = (parent: string, params: Record<string, string | readonly string[]>) => ({
  parent,
  parent_id: params.parentId as string,
})

const customFieldHandlersForParent = (parent: string) => [
  http.get(`${API_PREFIX}/${parent}/:parentId/custom_fields`, ({ params }) =>
    HttpResponse.json({
      data: [{ ...fixtures.customField, _route: echoRoute(parent, params) }],
      meta: {
        count: 1,
        page: 1,
        limit: 25,
        pages: 1,
        from: 1,
        to: 1,
        in: 1,
        previous: null,
        next: null,
      },
    }),
  ),
  http.get(`${API_PREFIX}/${parent}/:parentId/custom_fields/:id`, ({ params }) =>
    HttpResponse.json({ ...fixtures.customField, _route: echoRoute(parent, params) }),
  ),
  http.post(`${API_PREFIX}/${parent}/:parentId/custom_fields`, ({ params }) =>
    HttpResponse.json(
      { ...fixtures.customField, _route: echoRoute(parent, params) },
      { status: 201 },
    ),
  ),
  http.patch(`${API_PREFIX}/${parent}/:parentId/custom_fields/:id`, ({ params }) =>
    HttpResponse.json({
      ...fixtures.customField,
      value: 'cotton',
      _route: echoRoute(parent, params),
    }),
  ),
  http.delete(
    `${API_PREFIX}/${parent}/:parentId/custom_fields/:id`,
    () => new HttpResponse(null, { status: 204 }),
  ),
]

export const handlers = [
  ...PARENT_PATHS.flatMap(customFieldHandlersForParent),

  http.get(`${API_PREFIX}/custom_field_definitions`, () =>
    HttpResponse.json({
      data: [fixtures.customFieldDefinition],
      meta: {
        count: 1,
        page: 1,
        limit: 25,
        pages: 1,
        from: 1,
        to: 1,
        in: 1,
        previous: null,
        next: null,
      },
    }),
  ),
  http.get(`${API_PREFIX}/custom_field_definitions/:id`, () =>
    HttpResponse.json(fixtures.customFieldDefinition),
  ),
  http.post(`${API_PREFIX}/custom_field_definitions`, () =>
    HttpResponse.json(fixtures.customFieldDefinition, { status: 201 }),
  ),
  http.patch(`${API_PREFIX}/custom_field_definitions/:id`, () =>
    HttpResponse.json({ ...fixtures.customFieldDefinition, label: 'Updated label' }),
  ),
  http.delete(
    `${API_PREFIX}/custom_field_definitions/:id`,
    () => new HttpResponse(null, { status: 204 }),
  ),
]

/**
 * Thin SDK wrapper for the Brands Admin API.
 *
 * Pattern: plugins that ship a backend they own (a `spree_brands` gem,
 * for instance) wrap `adminClient.request<T>(...)` here in a small client
 * module. The wrappers add no logic — they're just typed signatures for
 * the endpoints the plugin's backend exposes. The dashboard's hooks and
 * components consume these wrappers, not `adminClient.request` directly,
 * so the plugin can rename, version, or swap backends in one place.
 *
 * See the `Custom Admin Endpoints` guide in the Spree docs for the
 * `adminClient.request` API.
 */

import type { PaginatedResponse } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import type { Brand, BrandCreateParams, BrandUpdateParams } from './types'

/**
 * Query-param shape accepted by the brands list endpoint. Wider than
 * @spree/admin-sdk's `ListParams` because `adminClient.request` only knows
 * the runtime shape (string-keyed) and `ListParams` is a closed interface.
 * In practice, callers pass the same `{ page, limit, sort, search, … }`
 * keys built-in resources accept.
 */
type BrandsListParams = Record<string, string | number | boolean | (string | number)[] | undefined>

export const brandsClient = {
  list: (params?: BrandsListParams) =>
    adminClient.request<PaginatedResponse<Brand>>('GET', '/brands', { params }),

  get: (id: string) => adminClient.request<Brand>('GET', `/brands/${id}`),

  create: (body: BrandCreateParams) => adminClient.request<Brand>('POST', '/brands', { body }),

  update: (id: string, body: BrandUpdateParams) =>
    adminClient.request<Brand>('PATCH', `/brands/${id}`, { body }),

  delete: (id: string) => adminClient.request<void>('DELETE', `/brands/${id}`),
}

import type {
  Catalog,
  CatalogAssignment,
  CatalogAssignParams,
  CatalogOrderMinimum,
  CatalogOrderMinimumParams,
  CatalogParams,
  CatalogQuantityRule,
  CatalogQuantityRuleParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useCatalog(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('catalogs', id ?? 'noop'),
    queryFn: () =>
      adminClient.catalogs.get(id as string, {
        expand: ['assignments', 'price_list', 'price_list.price_rules', 'order_minimums'],
      }),
    enabled: !!id,
  })
}

export function useCreateCatalog() {
  return useResourceMutation<Catalog, Error, CatalogParams>({
    mutationFn: (params) => adminClient.catalogs.create(params),
    invalidate: [['catalogs']],
    successMessage: i18n.t('admin.catalogs.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateCatalog(id: string) {
  return useResourceMutation<Catalog, Error, CatalogParams>({
    mutationFn: (params) => adminClient.catalogs.update(id, params),
    invalidate: [['catalogs'], ['catalogs', id]],
    successMessage: i18n.t('admin.catalogs.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteCatalog() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.catalogs.delete(id),
    invalidate: [['catalogs']],
    successMessage: i18n.t('admin.catalogs.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('catalogs', id) })
    },
  })
}

// ---------------------------------------------------------------------------
// Assortment
// ---------------------------------------------------------------------------

export function useCatalogProducts(catalogId: string | undefined, page = 1) {
  return useQuery({
    queryKey: useResourceKey('catalogs', catalogId ?? 'noop', 'products', `${page}`),
    queryFn: () => adminClient.catalogs.products.list(catalogId as string, { page, limit: 25 }),
    enabled: !!catalogId,
    placeholderData: (previous) => previous,
  })
}

export interface CatalogSavePayload {
  /** Settings PATCH body; omitted when the form is clean. */
  attributes?: CatalogParams
  /** Staged assortment additions, flushed on Save. */
  addProductIds?: string[]
  /** Staged assortment removals, flushed on Save. */
  removeProductIds?: string[]
}

/**
 * One-shot save for the catalog page: settings plus the staged membership
 * changes, in one mutation with one toast. Settings go first so a
 * validation failure aborts before any membership write.
 */
export function useSaveCatalog(catalogId: string) {
  return useResourceMutation<void, Error, CatalogSavePayload>({
    mutationFn: async ({ attributes, addProductIds = [], removeProductIds = [] }) => {
      if (attributes) await adminClient.catalogs.update(catalogId, attributes)
      if (removeProductIds.length > 0) {
        await adminClient.catalogs.products.delete(catalogId, removeProductIds)
      }
      if (addProductIds.length > 0) {
        await adminClient.catalogs.products.create(catalogId, addProductIds)
      }
    },
    invalidate: [['catalogs'], ['catalogs', catalogId], ['catalogs', catalogId, 'products']],
    successMessage: i18n.t('admin.catalogs.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/**
 * Copies the attached price list's products into the assortment — the
 * explicit act that turns a pricing-only overlay into a restrictive catalog.
 */
export function useImportCatalogPriceListProducts(catalogId: string) {
  return useResourceMutation<{ added_count: number }, Error, void>({
    mutationFn: () => adminClient.catalogs.importProducts(catalogId),
    invalidate: [
      ['catalogs', catalogId],
      ['catalogs', catalogId, 'products'],
    ],
    successMessage: i18n.t('admin.catalogs.messages.products_imported'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

// ---------------------------------------------------------------------------
// Assignments — who sees the catalog
// ---------------------------------------------------------------------------

export function useAssignCatalog(catalogId: string) {
  return useResourceMutation<CatalogAssignment, Error, CatalogAssignParams>({
    mutationFn: (params) => adminClient.catalogs.assign(catalogId, params),
    invalidate: [['catalogs', catalogId]],
    successMessage: i18n.t('admin.catalogs.messages.assigned'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useUnassignCatalog(catalogId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (assignmentId) => adminClient.catalogAssignments.delete(assignmentId),
    invalidate: [['catalogs', catalogId]],
    successMessage: i18n.t('admin.catalogs.messages.unassigned'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

// ---------------------------------------------------------------------------
// Commercial terms — what the buyer may order, and what the order must reach
// ---------------------------------------------------------------------------

/**
 * The per-variant quantity overrides. Paginated rather than capped: an
 * agreement can name terms for thousands of SKUs, and a silent limit would
 * hide the rest while still calling itself the list.
 */
export function useCatalogQuantityRules(catalogId: string | undefined, page = 1) {
  return useQuery({
    queryKey: useResourceKey('catalogs', catalogId ?? 'noop', 'quantity_rules', `${page}`),
    queryFn: () =>
      adminClient.catalogs.quantityRules.list(catalogId as string, { page, limit: 25 }),
    enabled: !!catalogId,
    placeholderData: (previous) => previous,
  })
}

export function useCreateCatalogQuantityRule(catalogId: string) {
  return useResourceMutation<CatalogQuantityRule, Error, CatalogQuantityRuleParams>({
    mutationFn: (params) => adminClient.catalogs.quantityRules.create(catalogId, params),
    invalidate: [
      ['catalogs', catalogId],
      ['catalogs', catalogId, 'quantity_rules'],
    ],
    successMessage: i18n.t('admin.catalogs.terms.messages.rule_created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useDeleteCatalogQuantityRule(catalogId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.catalogs.quantityRules.delete(catalogId, id),
    invalidate: [
      ['catalogs', catalogId],
      ['catalogs', catalogId, 'quantity_rules'],
    ],
    successMessage: i18n.t('admin.catalogs.terms.messages.rule_deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

export function useCreateCatalogOrderMinimum(catalogId: string) {
  return useResourceMutation<CatalogOrderMinimum, Error, CatalogOrderMinimumParams>({
    mutationFn: (params) => adminClient.catalogs.orderMinimums.create(catalogId, params),
    invalidate: [['catalogs'], ['catalogs', catalogId]],
    successMessage: i18n.t('admin.catalogs.terms.messages.minimum_created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useDeleteCatalogOrderMinimum(catalogId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.catalogs.orderMinimums.delete(catalogId, id),
    invalidate: [['catalogs'], ['catalogs', catalogId]],
    successMessage: i18n.t('admin.catalogs.terms.messages.minimum_deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

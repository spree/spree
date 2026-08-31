import type {
  Catalog,
  CatalogAssignment,
  CatalogAssignParams,
  CatalogParams,
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

/**
 * The catalog's assortment, each row carrying what the agreement charges for
 * it. The price is asked for here rather than in a second request because it
 * is read on the same rows: a product the agreement does not price has to be
 * visible beside the ones it does
 * (docs/plans/6.0-catalog-agreement-rework.md).
 */
export function useCatalogProducts(catalogId: string | undefined, page = 1) {
  return useQuery({
    queryKey: useResourceKey('catalogs', catalogId ?? 'noop', 'products', `${page}`),
    queryFn: () =>
      adminClient.catalogs.products.list(catalogId as string, {
        page,
        limit: 25,
        expand: ['catalog_price'],
      }),
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
  /**
   * Per-product quantity terms as edited, keyed by product id. A pair of
   * blanks clears that product's terms. Products named here that are not in
   * the assortment are added by the save — a term with nothing to apply to
   * is not a state worth being able to reach.
   */
  productTerms?: Record<
    string,
    { minimum_order_quantity: number | null; order_multiple: number | null }
  >
}

/**
 * One-shot save for the catalog page: settings plus the staged membership
 * changes, in one mutation with one toast. Settings go first so a
 * validation failure aborts before any membership write.
 */
export function useSaveCatalog(catalogId: string) {
  return useResourceMutation<void, Error, CatalogSavePayload>({
    mutationFn: async ({
      attributes,
      addProductIds = [],
      removeProductIds = [],
      productTerms = {},
    }) => {
      if (attributes) await adminClient.catalogs.update(catalogId, attributes)

      // Removals first: a product on its way out takes its terms with it, so
      // sending them afterwards would re-create rows the delete just cleared.
      if (removeProductIds.length > 0) {
        await adminClient.catalogs.products.delete(catalogId, removeProductIds)
      }
      if (addProductIds.length > 0) {
        await adminClient.catalogs.products.create(catalogId, addProductIds)
      }

      const termProductIds = Object.keys(productTerms)
      if (termProductIds.length > 0) {
        await adminClient.catalogs.productTerms.upsert(catalogId, { terms: productTerms })
      }
    },
    invalidate: [
      ['catalogs'],
      ['catalogs', catalogId],
      ['catalogs', catalogId, 'products'],
      ['catalogs', catalogId, 'product_terms'],
    ],
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

/** A catalog's per-product quantity terms, at the grain the editor states them. */
export function useCatalogProductTerms(catalogId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('catalogs', catalogId ?? 'noop', 'product_terms'),
    queryFn: () => adminClient.catalogs.productTerms.list(catalogId as string),
    enabled: !!catalogId,
  })
}

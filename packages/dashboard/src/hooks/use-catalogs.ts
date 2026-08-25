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
    queryFn: () => adminClient.catalogs.get(id as string, { expand: ['assignments'] }),
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
// Assortment — the ProductMembershipHooks shape ProductMembershipCard expects
// ---------------------------------------------------------------------------

export function useCatalogProducts(catalogId: string | undefined, page = 1) {
  return useQuery({
    queryKey: useResourceKey('catalogs', catalogId ?? 'noop', 'products', `${page}`),
    queryFn: () => adminClient.catalogs.products.list(catalogId as string, { page, limit: 25 }),
    enabled: !!catalogId,
    placeholderData: (previous) => previous,
  })
}

export function useAddCatalogProducts(catalogId: string) {
  return useResourceMutation<{ added_count: number }, Error, string[]>({
    mutationFn: (productIds) => adminClient.catalogs.products.create(catalogId, productIds),
    invalidate: [
      ['catalogs', catalogId, 'products'],
      ['catalogs', catalogId],
    ],
    successMessage: i18n.t('admin.catalogs.messages.products_added'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRemoveCatalogProduct(catalogId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (productId) => adminClient.catalogs.products.delete(catalogId, productId),
    invalidate: [
      ['catalogs', catalogId, 'products'],
      ['catalogs', catalogId],
    ],
    successMessage: i18n.t('admin.catalogs.messages.product_removed'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRemoveCatalogProducts(catalogId: string) {
  return useResourceMutation<unknown, Error, string[]>({
    mutationFn: (productIds) =>
      Promise.all(
        productIds.map((productId) => adminClient.catalogs.products.delete(catalogId, productId)),
      ),
    invalidate: [
      ['catalogs', catalogId, 'products'],
      ['catalogs', catalogId],
    ],
    successMessage: i18n.t('admin.catalogs.messages.products_removed'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRepositionCatalogProduct(catalogId: string) {
  return useResourceMutation<void, Error, { productId: string; new_position: number }>({
    mutationFn: ({ productId, new_position }) =>
      adminClient.catalogs.products.reposition(catalogId, productId, new_position),
    invalidate: [['catalogs', catalogId, 'products']],
    successMessage: false,
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

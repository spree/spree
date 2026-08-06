import type {
  ProductType,
  ProductTypeCreateParams,
  ProductTypeUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

interface UseProductTypesParams {
  page?: number
  limit?: number
}

export function useProductTypes({ page = 1, limit = 100 }: UseProductTypesParams = {}) {
  return useQuery({
    queryKey: useResourceKey('product-types', { page, limit }),
    queryFn: () => adminClient.productTypes.list({ page, limit }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useProductType(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('product-types', id ?? 'noop'),
    queryFn: () => adminClient.productTypes.get(id as string),
    enabled: !!id,
    staleTime: 1000 * 60 * 5,
  })
}

export function useCreateProductType() {
  return useResourceMutation<ProductType, Error, ProductTypeCreateParams>({
    mutationFn: (params) => adminClient.productTypes.create(params),
    invalidate: [['product-types']],
    successMessage: i18n.t('admin.product_types.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateProductType(id: string) {
  return useResourceMutation<ProductType, Error, ProductTypeUpdateParams>({
    mutationFn: (params) => adminClient.productTypes.update(id, params),
    invalidate: [['product-types'], ['product-types', id]],
    successMessage: i18n.t('admin.product_types.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/**
 * Backfills a type's option types and categories onto products that already
 * carry it. Additive — the only path from a type edit to existing products.
 */
export function useApplyProductTypeToProducts(id: string) {
  return useResourceMutation<{ products_count: number }, Error, void>({
    mutationFn: () => adminClient.productTypes.applyToProducts(id),
    invalidate: [['product-types'], ['products']],
    successMessage: i18n.t('admin.product_types.messages.applied_to_products'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteProductType() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.productTypes.delete(id),
    invalidate: [['product-types']],
    successMessage: i18n.t('admin.product_types.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('product-types', id) })
    },
  })
}

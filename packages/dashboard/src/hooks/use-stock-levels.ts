import type { StockLevel, StockLevelUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { type QueryKey, useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

interface UseStockLevelsParams {
  page?: number
  limit?: number
  stock_location_id_eq?: string
  variant_sku_or_variant_product_name_cont?: string
}

export function useStockLevels(params: UseStockLevelsParams = {}) {
  return useQuery({
    queryKey: useResourceKey('stock-levels', params),
    queryFn: () =>
      adminClient.stockLevels.list({
        page: params.page ?? 1,
        limit: params.limit ?? 25,
        // The stock-at-location panel renders the variant's product name +
        // SKU per row, so expand the association into the response.
        // Without this, only `variant_id` comes back and the row falls
        // back to displaying the prefixed ID.
        expand: ['variant'],
        ...(params.stock_location_id_eq && {
          stock_location_id_eq: params.stock_location_id_eq,
        }),
        ...(params.variant_sku_or_variant_product_name_cont && {
          variant_sku_or_variant_product_name_cont: params.variant_sku_or_variant_product_name_cont,
        }),
      }),
    enabled: !!params.stock_location_id_eq,
  })
}

export function useUpdateStockLevel(id: string, extraInvalidate: QueryKey[] = []) {
  return useResourceMutation<StockLevel, Error, StockLevelUpdateParams>({
    mutationFn: (params) => adminClient.stockLevels.update(id, params),
    invalidate: [['stock-levels'], ['stock-levels', id], ...extraInvalidate],
    successMessage: i18n.t('admin.stock_levels.messages.stock_updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteStockLevel() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.stockLevels.delete(id),
    invalidate: [['stock-levels']],
    successMessage: i18n.t('admin.stock_levels.messages.stock_level_deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('stock-levels', id) })
    },
  })
}

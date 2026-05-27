import type { StockItem, StockItemUpdateParams } from '@spree/admin-sdk'
import { type QueryKey, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const stockItemsQueryKey = ['stock-items'] as const

export function stockItemQueryKey(id: string) {
  return ['stock-items', id] as const
}

interface UseStockItemsParams {
  page?: number
  limit?: number
  stock_location_id_eq?: string
  variant_sku_or_variant_product_name_cont?: string
}

export function useStockItems(params: UseStockItemsParams = {}) {
  return useQuery({
    queryKey: [...stockItemsQueryKey, params],
    queryFn: () =>
      adminClient.stockItems.list({
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

export function useUpdateStockItem(id: string, extraInvalidate: QueryKey[] = []) {
  return useResourceMutation<StockItem, Error, StockItemUpdateParams>({
    mutationFn: (params) => adminClient.stockItems.update(id, params),
    invalidate: [stockItemsQueryKey, stockItemQueryKey(id), ...extraInvalidate],
    successMessage: 'Stock updated',
    errorMessage: 'Failed to update stock',
  })
}

export function useDeleteStockItem() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.stockItems.delete(id),
    invalidate: [stockItemsQueryKey],
    successMessage: 'Stock item deleted',
    errorMessage: 'Failed to delete stock item',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: stockItemQueryKey(id) })
    },
  })
}

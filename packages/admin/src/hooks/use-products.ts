import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'
import type { FilterRule } from '@/lib/table-registry'

interface UseProductsParams {
  page?: number
  limit?: number
  sort?: string
  search?: string
  filters?: FilterRule[]
}

export function useProducts({
  page = 1,
  limit = 25,
  sort = '-updated_at',
  search,
  filters = [],
}: UseProductsParams = {}) {
  return useQuery({
    queryKey: ['products', { page, limit, sort, search, filters }],
    queryFn: async () => {
      const params: Record<string, unknown> = { page, limit, sort }

      if (search) {
        params.name_cont = search
      }

      // Convert FilterRule[] to Ransack params
      for (const filter of filters) {
        const key = `${filter.field}_${filter.operator}`
        params[key] = filter.value
      }

      return adminClient.products.list(params)
    },
  })
}

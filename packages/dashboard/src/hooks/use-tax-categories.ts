import type {
  TaxCategory,
  TaxCategoryCreateParams,
  TaxCategoryUpdateParams,
} from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const taxCategoriesQueryKey = ['tax-categories'] as const

export function taxCategoryQueryKey(id: string) {
  return ['tax-categories', id] as const
}

interface UseTaxCategoriesParams {
  page?: number
  limit?: number
}

export function useTaxCategories({ page = 1, limit = 100 }: UseTaxCategoriesParams = {}) {
  return useQuery({
    queryKey: [...taxCategoriesQueryKey, { page, limit }],
    queryFn: () => adminClient.taxCategories.list({ page, limit }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useTaxCategory(id: string | undefined) {
  return useQuery({
    queryKey: id ? taxCategoryQueryKey(id) : ['tax-categories', 'noop'],
    queryFn: () => adminClient.taxCategories.get(id as string),
    enabled: !!id,
  })
}

export function useCreateTaxCategory() {
  return useResourceMutation<TaxCategory, Error, TaxCategoryCreateParams>({
    mutationFn: (params) => adminClient.taxCategories.create(params),
    invalidate: [taxCategoriesQueryKey],
    successMessage: 'Tax category created',
    errorMessage: 'Failed to create tax category',
  })
}

export function useUpdateTaxCategory(id: string) {
  return useResourceMutation<TaxCategory, Error, TaxCategoryUpdateParams>({
    mutationFn: (params) => adminClient.taxCategories.update(id, params),
    invalidate: [taxCategoriesQueryKey, taxCategoryQueryKey(id)],
    successMessage: 'Tax category updated',
    errorMessage: 'Failed to update tax category',
  })
}

export function useDeleteTaxCategory() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.taxCategories.delete(id),
    invalidate: [taxCategoriesQueryKey],
    successMessage: 'Tax category deleted',
    errorMessage: 'Failed to delete tax category',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: taxCategoryQueryKey(id) })
    },
  })
}

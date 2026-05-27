import type { OptionType, OptionTypeCreateParams, OptionTypeUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceMutation } from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

export const optionTypesQueryKey = ['option-types'] as const

export function optionTypeQueryKey(id: string) {
  return ['option-types', id] as const
}

interface UseOptionTypesParams {
  page?: number
  limit?: number
  q?: Record<string, unknown>
}

export function useOptionTypes({ page = 1, limit = 100, q }: UseOptionTypesParams = {}) {
  return useQuery({
    queryKey: [...optionTypesQueryKey, { page, limit, q }],
    queryFn: () =>
      adminClient.optionTypes.list({
        page,
        limit,
        q,
        expand: ['option_values'],
      }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useOptionType(id: string | undefined) {
  return useQuery({
    queryKey: id ? optionTypeQueryKey(id) : ['option-types', 'noop'],
    queryFn: () => adminClient.optionTypes.get(id as string, { expand: ['option_values'] }),
    enabled: !!id,
  })
}

export function useCreateOptionType() {
  return useResourceMutation<OptionType, Error, OptionTypeCreateParams>({
    mutationFn: (params) => adminClient.optionTypes.create(params),
    invalidate: [optionTypesQueryKey],
    successMessage: 'Option type created',
    errorMessage: 'Failed to create option type',
  })
}

export function useUpdateOptionType(id: string) {
  return useResourceMutation<OptionType, Error, OptionTypeUpdateParams>({
    mutationFn: (params) => adminClient.optionTypes.update(id, params),
    invalidate: [optionTypesQueryKey, optionTypeQueryKey(id)],
    successMessage: 'Option type updated',
    errorMessage: 'Failed to update option type',
  })
}

export function useDeleteOptionType() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.optionTypes.delete(id),
    invalidate: [optionTypesQueryKey],
    successMessage: 'Option type deleted',
    errorMessage: 'Failed to delete option type',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: optionTypeQueryKey(id) })
    },
  })
}

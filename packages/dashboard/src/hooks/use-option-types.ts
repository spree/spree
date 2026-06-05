import type { OptionType, OptionTypeCreateParams, OptionTypeUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

interface UseOptionTypesParams {
  page?: number
  limit?: number
  q?: Record<string, unknown>
}

export function useOptionTypes({ page = 1, limit = 100, q }: UseOptionTypesParams = {}) {
  return useQuery({
    queryKey: useResourceKey('option-types', { page, limit, q }),
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
    queryKey: useResourceKey('option-types', id ?? 'noop'),
    queryFn: () => adminClient.optionTypes.get(id as string, { expand: ['option_values'] }),
    enabled: !!id,
  })
}

export function useCreateOptionType() {
  return useResourceMutation<OptionType, Error, OptionTypeCreateParams>({
    mutationFn: (params) => adminClient.optionTypes.create(params),
    invalidate: [['option-types']],
    successMessage: 'Option type created',
    errorMessage: 'Failed to create option type',
  })
}

export function useUpdateOptionType(id: string) {
  return useResourceMutation<OptionType, Error, OptionTypeUpdateParams>({
    mutationFn: (params) => adminClient.optionTypes.update(id, params),
    invalidate: [['option-types'], ['option-types', id]],
    successMessage: 'Option type updated',
    errorMessage: 'Failed to update option type',
  })
}

export function useDeleteOptionType() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.optionTypes.delete(id),
    invalidate: [['option-types']],
    successMessage: 'Option type deleted',
    errorMessage: 'Failed to delete option type',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('option-types', id) })
    },
  })
}

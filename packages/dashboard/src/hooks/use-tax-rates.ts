import type { TaxRate, TaxRateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useTaxRate(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('tax-rates', id ?? 'noop'),
    queryFn: () => adminClient.taxRates.get(id as string),
    enabled: !!id,
  })
}

export function useCreateTaxRate() {
  return useResourceMutation<TaxRate, Error, TaxRateParams>({
    mutationFn: (params) => adminClient.taxRates.create(params),
    invalidate: [['tax-rates']],
    successMessage: i18n.t('admin.tax_rates.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateTaxRate(id: string) {
  return useResourceMutation<TaxRate, Error, TaxRateParams>({
    mutationFn: (params) => adminClient.taxRates.update(id, params),
    invalidate: [['tax-rates'], ['tax-rates', id]],
    successMessage: i18n.t('admin.tax_rates.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteTaxRate() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.taxRates.delete(id),
    invalidate: [['tax-rates']],
    successMessage: i18n.t('admin.tax_rates.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('tax-rates', id) })
    },
  })
}

/**
 * The tax engines this installation can use, each declaring what it cannot
 * handle. Registered in code rather than stored, so this never changes within
 * a session.
 */
export function useTaxProviders() {
  return useQuery({
    queryKey: useResourceKey('tax-providers'),
    queryFn: () => adminClient.taxProviders.list(),
    staleTime: Number.POSITIVE_INFINITY,
  })
}

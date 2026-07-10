import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

export function useTaxRates() {
  return useQuery({
    queryKey: useResourceKey('tax-rates'),
    queryFn: async () =>
      adminClient.request('GET', '/tax_rates', {
        params: { per_page: 100 },
      }),
  })
}

export function useTaxRate(id: string | undefined, enabled = true) {
  return useQuery({
    queryKey: useResourceKey('tax-rates', id ?? 'noop'),
    queryFn: async () => adminClient.request('GET', `/tax_rates/${id}`),
    enabled: !!id && enabled,
  })
}

export function useCreateTaxRate() {
  return useResourceMutation({
    mutationFn: async (params: Record<string, unknown>) =>
      adminClient.request('POST', '/tax_rates', { body: params }),
    invalidate: [['tax-rates']],
    successMessage: i18n.t('admin.tax_rates.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateTaxRate() {
  return useResourceMutation({
    mutationFn: async (params: Record<string, unknown> & { id: string }) => {
      const { id, ...data } = params
      return adminClient.request('PATCH', `/tax_rates/${id}`, { body: data })
    },
    invalidate: [['tax-rates']],
    successMessage: i18n.t('admin.tax_rates.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteTaxRate() {
  return useResourceMutation({
    mutationFn: async ({ id }: { id: string }) =>
      adminClient.request('DELETE', `/tax_rates/${id}`),
    invalidate: [['tax-rates']],
    successMessage: i18n.t('admin.tax_rates.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

export function useTaxCategories() {
  return useQuery({
    queryKey: useResourceKey('tax-categories'),
    queryFn: async () =>
      adminClient.request('GET', '/tax_categories', {
        params: { per_page: 100 },
      }),
  })
}

export function useZones() {
  return useQuery({
    queryKey: useResourceKey('zones'),
    queryFn: async () =>
      adminClient.request('GET', '/zones', {
        params: { per_page: 100 },
      }),
  })
}

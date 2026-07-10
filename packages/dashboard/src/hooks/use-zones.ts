import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

export function useZones() {
  return useQuery({
    queryKey: useResourceKey('zones'),
    queryFn: async () =>
      adminClient.request('GET', '/zones', {
        params: { per_page: 100 },
      }),
  })
}

export function useZone(id: string | undefined, enabled = true) {
  return useQuery({
    queryKey: useResourceKey('zones', id ?? 'noop'),
    queryFn: async () => adminClient.request('GET', `/zones/${id}`),
    enabled: !!id && enabled,
  })
}

export function useCreateZone() {
  return useResourceMutation({
    mutationFn: async (params: Record<string, unknown>) =>
      adminClient.request('POST', '/zones', { body: params }),
    invalidate: [['zones']],
    successMessage: i18n.t('admin.zones.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateZone() {
  return useResourceMutation({
    mutationFn: async (params: Record<string, unknown> & { id: string }) => {
      const { id, ...data } = params
      return adminClient.request('PATCH', `/zones/${id}`, { body: data })
    },
    invalidate: [['zones']],
    successMessage: i18n.t('admin.zones.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteZone() {
  return useResourceMutation({
    mutationFn: async ({ id }: { id: string }) =>
      adminClient.request('DELETE', `/zones/${id}`),
    invalidate: [['zones']],
    successMessage: i18n.t('admin.zones.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

export function useCountries() {
  return useQuery({
    queryKey: useResourceKey('countries'),
    queryFn: async () =>
      adminClient.request('GET', '/countries', {
        params: { per_page: 500 },
      }),
  })
}

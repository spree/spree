import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

export function useShippingMethods() {
  return useQuery({
    queryKey: useResourceKey('shipping-methods'),
    queryFn: async () =>
      adminClient.request('GET', '/shipping_methods', {
        params: { per_page: 100 },
      }),
  })
}

export function useShippingMethod(id: string | undefined, enabled = true) {
  return useQuery({
    queryKey: useResourceKey('shipping-methods', id ?? 'noop'),
    queryFn: async () => adminClient.request('GET', `/shipping_methods/${id}`),
    enabled: !!id && enabled,
  })
}

export function useCreateShippingMethod() {
  return useResourceMutation({
    mutationFn: async (params: Record<string, unknown>) =>
      adminClient.request('POST', '/shipping_methods', { body: params }),
    invalidate: [['shipping-methods']],
    successMessage: i18n.t('admin.shipping_methods.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateShippingMethod() {
  return useResourceMutation({
    mutationFn: async (params: Record<string, unknown> & { id: string }) => {
      const { id, ...data } = params
      return adminClient.request('PATCH', `/shipping_methods/${id}`, { body: data })
    },
    invalidate: [['shipping-methods']],
    successMessage: i18n.t('admin.shipping_methods.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteShippingMethod() {
  return useResourceMutation({
    mutationFn: async ({ id }: { id: string }) =>
      adminClient.request('DELETE', `/shipping_methods/${id}`),
    invalidate: [['shipping-methods']],
    successMessage: i18n.t('admin.shipping_methods.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

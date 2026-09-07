import type { Supplier, SupplierCreateParams, SupplierUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useSuppliers(params?: { limit?: number; search?: string }) {
  return useQuery({
    queryKey: useResourceKey('suppliers', JSON.stringify(params ?? {})),
    queryFn: () => adminClient.suppliers.list(params),
  })
}

export function useSupplier(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('suppliers', id ?? 'noop'),
    queryFn: () => adminClient.suppliers.get(id as string),
    enabled: !!id,
  })
}

export function useCreateSupplier() {
  return useResourceMutation<Supplier, Error, SupplierCreateParams>({
    mutationFn: (params) => adminClient.suppliers.create(params),
    invalidate: [['suppliers']],
    successMessage: i18n.t('admin.suppliers.messages.created'),
    errorMessage: i18n.t('admin.suppliers.errors.failed_to_create'),
  })
}

export function useUpdateSupplier(id: string) {
  return useResourceMutation<Supplier, Error, SupplierUpdateParams>({
    mutationFn: (params) => adminClient.suppliers.update(id, params),
    invalidate: [['suppliers'], ['suppliers', id]],
    successMessage: i18n.t('admin.suppliers.messages.saved'),
    errorMessage: i18n.t('admin.suppliers.errors.failed_to_save'),
  })
}

export function useDeleteSupplier() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.suppliers.delete(id),
    invalidate: [['suppliers']],
    successMessage: i18n.t('admin.suppliers.messages.deleted'),
    errorMessage: i18n.t('admin.suppliers.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('suppliers', id) })
    },
  })
}

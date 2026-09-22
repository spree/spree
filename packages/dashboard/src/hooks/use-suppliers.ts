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

/**
 * A supplier picker, for the create form and the purchase orders filter.
 *
 * Searches on the same predicate the suppliers table searches on, so "how you
 * look for a supplier" is defined once. `search:` — which the customer and
 * order pickers use — is a Ransack *scope* those models declare and this one
 * does not, so sent here it is quietly ignored and every supplier comes back.
 */
export function supplierAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (query: string) =>
      adminClient.suppliers.list({
        name_or_contact_name_or_email_cont: query,
        limit: 100,
        sort: 'name',
        fields: ['name'],
      }),
    hydrate: (ids: string[]) => adminClient.suppliers.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (supplier: Supplier) => supplier.name ?? supplier.id,
    placeholder: i18n.t('admin.suppliers.autocomplete.placeholder'),
    emptyText: i18n.t('admin.suppliers.autocomplete.empty'),
  }
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
    // These screens have no inline error surface.
    showValidationErrors: true,
  })
}

export function useUpdateSupplier(id: string) {
  return useResourceMutation<Supplier, Error, SupplierUpdateParams>({
    mutationFn: (params) => adminClient.suppliers.update(id, params),
    invalidate: [['suppliers'], ['suppliers', id]],
    successMessage: i18n.t('admin.suppliers.messages.saved'),
    errorMessage: i18n.t('admin.suppliers.errors.failed_to_save'),
    // These screens have no inline error surface.
    showValidationErrors: true,
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
    // These screens have no inline error surface.
    showValidationErrors: true,
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('suppliers', id) })
    },
  })
}

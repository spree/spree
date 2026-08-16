import type {
  ListParams,
  Vendor,
  VendorCreateParams,
  VendorInviteParams,
  VendorRejectParams,
  VendorSuspendParams,
  VendorUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useVendors(params?: ListParams & Record<string, unknown>) {
  return useQuery({
    queryKey: useResourceKey('vendors', params ? JSON.stringify(params) : 'all'),
    queryFn: () => adminClient.vendors.list(params),
  })
}

/**
 * Shared config for any `<ResourceMultiAutocomplete>` picking vendors (today
 * the products table filter). Pass a unique `queryKey` per instance so
 * independent caches don't collide.
 */
export function vendorAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) => adminClient.vendors.list({ name_cont: q, limit: 20, sort: 'name' }),
    hydrate: (ids: string[]) => adminClient.vendors.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (vendor: Vendor) => vendor.name ?? vendor.id,
    placeholder: i18n.t('admin.vendors.autocomplete.placeholder'),
    emptyText: i18n.t('admin.vendors.autocomplete.empty'),
  }
}

export function useVendor(id: string | undefined) {
  const key = useResourceKey('vendors', id ?? 'noop')
  return useQuery({
    queryKey: key,
    queryFn: () => adminClient.vendors.get(id as string),
    enabled: !!id,
  })
}

export function useCreateVendor() {
  return useResourceMutation<Vendor, Error, VendorCreateParams>({
    mutationFn: (params) => adminClient.vendors.create(params),
    invalidate: [['vendors']],
    successMessage: i18n.t('admin.vendors.messages.created'),
    errorMessage: i18n.t('admin.vendors.messages.create_failed'),
  })
}

export function useUpdateVendor(id: string) {
  return useResourceMutation<Vendor, Error, VendorUpdateParams>({
    mutationFn: (params) => adminClient.vendors.update(id, params),
    invalidate: [['vendors'], ['vendors', id]],
    successMessage: i18n.t('admin.vendors.messages.updated'),
    errorMessage: i18n.t('admin.vendors.messages.update_failed'),
  })
}

export function useDeleteVendor() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.vendors.delete(id),
    invalidate: [['vendors']],
    successMessage: i18n.t('admin.vendors.messages.deleted'),
    errorMessage: i18n.t('admin.vendors.messages.delete_failed'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('vendors', id) })
    },
  })
}

export function useInviteVendor(id: string) {
  return useResourceMutation<Vendor, Error, VendorInviteParams>({
    mutationFn: (params) => adminClient.vendors.invite(id, params),
    invalidate: [['vendors'], ['vendors', id]],
    successMessage: i18n.t('admin.vendors.messages.invited'),
    errorMessage: i18n.t('admin.vendors.messages.invite_failed'),
  })
}

export function useApproveVendor(id: string) {
  return useResourceMutation<Vendor, Error, void>({
    mutationFn: () => adminClient.vendors.approve(id),
    invalidate: [['vendors'], ['vendors', id]],
    successMessage: i18n.t('admin.vendors.messages.approved'),
    errorMessage: i18n.t('admin.vendors.messages.approve_failed'),
  })
}

export function useSuspendVendor(id: string) {
  return useResourceMutation<Vendor, Error, VendorSuspendParams | undefined>({
    mutationFn: (params) => adminClient.vendors.suspend(id, params ?? undefined),
    invalidate: [['vendors'], ['vendors', id]],
    successMessage: i18n.t('admin.vendors.messages.suspended'),
    errorMessage: i18n.t('admin.vendors.messages.suspend_failed'),
  })
}

export function useRejectVendor(id: string) {
  return useResourceMutation<Vendor, Error, VendorRejectParams | undefined>({
    mutationFn: (params) => adminClient.vendors.reject(id, params ?? undefined),
    invalidate: [['vendors'], ['vendors', id]],
    successMessage: i18n.t('admin.vendors.messages.rejected'),
    errorMessage: i18n.t('admin.vendors.messages.reject_failed'),
  })
}

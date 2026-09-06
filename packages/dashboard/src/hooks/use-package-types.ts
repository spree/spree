import type {
  PackageType,
  PackageTypeCreateParams,
  PackageTypeUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function usePackageType(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('package-types', id ?? 'noop'),
    queryFn: () => adminClient.packageTypes.get(id as string),
    enabled: !!id,
  })
}

export function useCreatePackageType() {
  return useResourceMutation<PackageType, Error, PackageTypeCreateParams>({
    mutationFn: (params) => adminClient.packageTypes.create(params),
    invalidate: [['package-types']],
    successMessage: i18n.t('admin.package_types.messages.added'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdatePackageType(id: string) {
  return useResourceMutation<PackageType, Error, PackageTypeUpdateParams>({
    mutationFn: (params) => adminClient.packageTypes.update(id, params),
    invalidate: [['package-types'], ['package-types', id]],
    successMessage: i18n.t('admin.package_types.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeletePackageType() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.packageTypes.delete(id),
    invalidate: [['package-types']],
    successMessage: i18n.t('admin.package_types.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('package-types', id) })
    },
  })
}

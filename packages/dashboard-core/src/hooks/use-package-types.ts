import type { PaginationMeta } from '@spree/dashboard-ui'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'
import {
  getApiClient,
  type PanelPackageType,
  type PanelPackageTypeCreateParams,
  type PanelPackageTypeParams,
} from '../api-client'
import { useResourceKey, useResourceKeyBuilder } from '../lib/query-keys'
import { useResourceMutation } from './use-resource-mutation'

/**
 * The registered panel's package-type resource.
 *
 * Throws rather than answering undefined: every hook here is only reachable
 * from the packaging page, and a panel that routes to it without registering
 * the resource is misconfigured — failing at the call site says so far more
 * clearly than a handful of "cannot read property of undefined" errors.
 */
function resource() {
  const packageTypes = getApiClient().packageTypes
  if (!packageTypes) {
    throw new Error(
      '@spree/dashboard-core: this panel registered no `packageTypes` resource, so the ' +
        'package-types page cannot load. Add one in setApiClient(), or drop the route.',
    )
  }
  return packageTypes
}

export function usePackageType(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('package-types', id ?? 'noop'),
    queryFn: () => {
      const get = resource().get
      if (!get) throw new Error('This panel cannot read a single package type.')
      return get(id as string)
    },
    enabled: !!id,
  })
}

export function useCreatePackageType() {
  return useResourceMutation<PanelPackageType, Error, PanelPackageTypeCreateParams>({
    mutationFn: (params) => {
      const create = resource().create
      if (!create) throw new Error('This panel cannot create package types.')
      return create(params)
    },
    invalidate: [['package-types'], ['panel-form-carton-package-types']],
    successMessage: i18n.t('admin.package_types.messages.added'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdatePackageType(id: string) {
  return useResourceMutation<PanelPackageType, Error, PanelPackageTypeParams>({
    mutationFn: (params) => {
      const update = resource().update
      if (!update) throw new Error('This panel cannot update package types.')
      return update(id, params)
    },
    invalidate: [['package-types'], ['package-types', id], ['panel-form-carton-package-types']],
    successMessage: i18n.t('admin.package_types.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeletePackageType() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => {
      const remove = resource().delete
      if (!remove) throw new Error('This panel cannot delete package types.')
      return remove(id)
    },
    invalidate: [['package-types'], ['panel-form-carton-package-types']],
    successMessage: i18n.t('admin.package_types.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('package-types', id) })
    },
  })
}

/**
 * Whether this panel's API can write packaging at all. A panel registering
 * only `list` gets the variant editor's carton picker and no settings page,
 * so the page hides everything that would write.
 */
export function canWritePackageTypes(): boolean {
  const packageTypes = getApiClient().packageTypes
  return typeof packageTypes?.create === 'function' && typeof packageTypes?.get === 'function'
}

/** Whether this panel's API offers deletion, which not every one does. */
export function canDeletePackageTypes(): boolean {
  return typeof getApiClient().packageTypes?.delete === 'function'
}

/**
 * One page of packaging, for `ResourceTable`'s own query. Not a hook — the
 * table calls it with the search params it has already parsed.
 */
export function listPackageTypes(params: Record<string, unknown>) {
  return resource().list(params) as Promise<{
    data: PanelPackageType[]
    meta: PaginationMeta
  }>
}

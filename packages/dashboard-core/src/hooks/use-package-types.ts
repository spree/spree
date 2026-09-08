import type { PaginationMeta } from '@spree/dashboard-ui'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'
import {
  getApiClient,
  type PanelPackageType,
  type PanelPackageTypeCreateParams,
  type PanelPackageTypeParams,
  type PanelPackageTypeWrites,
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

/**
 * The same resource narrowed to the writing shape.
 *
 * The narrowing is checked once here rather than at each call site: the page
 * only renders its sheets when `canWritePackageTypes()` is true, and the
 * panel's registration is what makes that so.
 */
function writableResource(): PanelPackageTypeWrites {
  const packageTypes = resource()
  if (!('create' in packageTypes)) {
    throw new Error(
      '@spree/dashboard-core: this panel registered `packageTypes` reads only, so packaging ' +
        'cannot be written. Register get/create/update, or drop the settings route.',
    )
  }
  return packageTypes
}

export function usePackageType(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('package-types', id ?? 'noop'),
    queryFn: () => writableResource().get(id as string),
    enabled: !!id,
  })
}

export function useCreatePackageType() {
  return useResourceMutation<PanelPackageType, Error, PanelPackageTypeCreateParams>({
    mutationFn: (params) => writableResource().create(params),
    invalidate: [['package-types'], ['panel-form-carton-package-types']],
    successMessage: i18n.t('admin.package_types.messages.added'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdatePackageType(id: string) {
  return useResourceMutation<PanelPackageType, Error, PanelPackageTypeParams>({
    mutationFn: (params) => writableResource().update(id, params),
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
      const remove = writableResource().delete
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
  if (packageTypes === undefined) return false

  // All three, not just `create`: the page renders Edit off this answer, and
  // a plain JavaScript host can register a partial object the write shape's
  // type would have refused.
  return ['get', 'create', 'update'].every((method) => method in packageTypes)
}

/** Whether this panel's API offers deletion, which not every one does. */
export function canDeletePackageTypes(): boolean {
  const packageTypes = getApiClient().packageTypes
  return packageTypes !== undefined && 'delete' in packageTypes
}

/**
 * One page of packaging, for `ResourceTable`'s own query. Not a hook — the
 * table calls it with the search params it has already parsed.
 */
export function listPackageTypes(params: Record<string, unknown>) {
  // `owner: 'mine'` — the settings page shows what this panel's principal
  // owns, never another owner's rows. On the operator's panel every row is
  // theirs and the param is ignored; on a seller's it hides the
  // marketplace's shared packaging, which the seller reads through the
  // variant editor's carton picker instead. A mixed list read as "packaging
  // is configured" while the seller had recorded none.
  return resource().list({ ...params, owner: 'mine' }) as Promise<{
    data: PanelPackageType[]
    meta: PaginationMeta
  }>
}

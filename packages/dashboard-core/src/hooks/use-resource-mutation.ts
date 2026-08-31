import { SpreeError } from '@spree/admin-sdk'
import { toastManager } from '@spree/dashboard-ui'
import {
  type QueryKey,
  type UseMutationOptions,
  useMutation,
  useQueryClient,
} from '@tanstack/react-query'
import { i18n } from '../lib/i18n'
import { withStoreScope } from '../lib/query-keys'
import { useTenantId } from '../providers/tenant-provider'

interface UseResourceMutationOptions<TData, TError, TVariables>
  extends Omit<UseMutationOptions<TData, TError, TVariables>, 'onSuccess' | 'onError'> {
  /**
   * Query keys to invalidate after success. Pass logical keys without
   * tenant id (e.g. `[['channels'], ['channels', id]]`) — the hook injects the
   * current tenant id at position 1 automatically so invalidation matches the
   * store-scoped keys used by `ResourceTable` and other queries.
   *
   * Mutations that change setup-task state (see `Spree.store_setup_tasks` on
   * the backend) must also invalidate `[STORE_QUERY_RESOURCE]` so the Getting
   * Started checklist and the nav progress badge stay live.
   */
  invalidate?: QueryKey[]
  /**
   * Key segments that must NOT be refreshed, even when `invalidate` matches
   * them by prefix. `invalidate: [['categories', id]]` also sweeps nested
   * lists like `['categories', id, 'products']`; passing `['products']` here
   * holds those back.
   *
   * Use it where a parent's own save runs alongside writes to one of its
   * nested collections: refreshing the collection from the parent's mutation
   * lands mid-save, painting the pre-save rows for a frame before the real
   * state arrives.
   */
  doNotInvalidate?: string[]
  /** Toast on success. Pass `false` to disable. Default `'Saved'`. */
  successMessage?: string | false
  /**
   * Toast on error. Pass `false` to disable. Default `'Something went wrong'`.
   *
   * 422 validation errors never toast — callers that surface them inline via
   * `mapSpreeErrorsToForm` would otherwise show the same problem twice. The
   * toast is reserved for failures the form can't render (network, 5xx,
   * auth, gateway).
   */
  errorMessage?: string | false
  /** Forwarded onSuccess callback. Runs after invalidation + toast. */
  onSuccess?: UseMutationOptions<TData, TError, TVariables>['onSuccess']
  /** Forwarded onError callback. Runs after error toast. */
  onError?: UseMutationOptions<TData, TError, TVariables>['onError']
}

/**
 * Wrapper around `useMutation` that bundles the two patterns every resource
 * mutation needs: query invalidation and success/error toasts.
 *
 * Replaces the per-page `try/catch + toast.success/toast.error` boilerplate.
 *
 * ```ts
 * const updateProduct = useResourceMutation({
 *   mutationFn: (params) => adminClient.products.update(id, params),
 *   invalidate: [productQueryKey(id), productsQueryKey],
 *   successMessage: 'Product saved',
 *   errorMessage: 'Failed to save product',
 * })
 * ```
 */
export function useResourceMutation<TData = unknown, TError = Error, TVariables = void>(
  options: UseResourceMutationOptions<TData, TError, TVariables>,
) {
  const queryClient = useQueryClient()
  const tenantId = useTenantId()
  const {
    invalidate,
    doNotInvalidate,
    successMessage = i18n.t('admin.messages.saved'),
    errorMessage = i18n.t('admin.errors.generic'),
    onSuccess,
    onError,
    ...rest
  } = options

  return useMutation<TData, TError, TVariables>({
    ...rest,
    onSuccess: (data, variables, onMutateResult, ctx) => {
      if (invalidate) {
        for (const key of invalidate) {
          const scoped = withStoreScope(key, tenantId)
          queryClient.invalidateQueries({
            queryKey: scoped,
            predicate: doNotInvalidate?.length
              ? (query) => !query.queryKey.some((part) => doNotInvalidate.includes(part as string))
              : undefined,
          })
        }
      }
      if (successMessage !== false) {
        toastManager.add({ type: 'success', title: successMessage })
      }
      return onSuccess?.(data, variables, onMutateResult, ctx)
    },
    onError: (error, variables, onMutateResult, ctx) => {
      if (errorMessage !== false && !isValidationError(error)) {
        toastManager.add({ type: 'error', title: errorMessage })
      }
      return onError?.(error, variables, onMutateResult, ctx)
    },
  })
}

// 422 with `details` means the model rejected the payload (e.g., "Code can't
// be blank"). The form renders these next to the offending input via
// `mapSpreeErrorsToForm`, so toasting the same thing would just be noise.
function isValidationError(error: unknown): boolean {
  return error instanceof SpreeError && error.status === 422
}

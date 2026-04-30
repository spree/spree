import {
  type QueryKey,
  type UseMutationOptions,
  useMutation,
  useQueryClient,
} from '@tanstack/react-query'
import { toast } from 'sonner'

interface UseResourceMutationOptions<TData, TError, TVariables>
  extends Omit<UseMutationOptions<TData, TError, TVariables>, 'onSuccess' | 'onError'> {
  /** Query keys to invalidate after success. Wrap singletons: `[orderQueryKey(id)]`. */
  invalidate?: QueryKey[]
  /** Toast on success. Pass `false` to disable. Default `'Saved'`. */
  successMessage?: string | false
  /** Toast on error. Pass `false` to disable. Default `'Something went wrong'`. */
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
  const {
    invalidate,
    successMessage = 'Saved',
    errorMessage = 'Something went wrong',
    onSuccess,
    onError,
    ...rest
  } = options

  return useMutation<TData, TError, TVariables>({
    ...rest,
    onSuccess: (data, variables, onMutateResult, ctx) => {
      if (invalidate) {
        for (const key of invalidate) {
          queryClient.invalidateQueries({ queryKey: key })
        }
      }
      if (successMessage !== false) {
        toast.success(successMessage)
      }
      return onSuccess?.(data, variables, onMutateResult, ctx)
    },
    onError: (error, variables, onMutateResult, ctx) => {
      if (errorMessage !== false) {
        toast.error(errorMessage)
      }
      return onError?.(error, variables, onMutateResult, ctx)
    },
  })
}

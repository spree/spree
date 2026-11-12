import { toastManager } from '@spree/dashboard-ui'
import { useCallback, useState } from 'react'
import { i18n } from '../lib/i18n'
import {
  NO_SERVER_ERRORS,
  offscreenSummaryOf,
  readServerErrors,
  type ServerErrorState,
  serverErrorStateFrom,
  withoutField,
} from '../lib/server-errors'

export { readServerErrors, type ServerErrors } from '../lib/server-errors'

/**
 * Toasts a failed write in the words a form would show it, for a dialog with
 * no inline place for the message. A plain `useMutation` with no `onError` is
 * otherwise silent: the dialog just stays open.
 *
 * @param error what the mutation rejected with
 */
export function toastMutationError(error: unknown): void {
  const title =
    readServerErrors(error)?.root ??
    (error instanceof Error && error.message ? error.message : i18n.t('admin.errors.generic'))
  toastManager.add({ type: 'error', title })
}

/**
 * A rejected save's messages for a form kept in plain `useState`, read the way
 * `mapSpreeErrorsToForm` reads them for React Hook Form: the same translated
 * per-field messages, and the summary under `root`.
 *
 * Pair it with a mutation that does not toast field errors
 * (`showValidationErrors` off): the message then shows once, beside the
 * input to fix.
 *
 * ```tsx
 * const serverErrors = useServerErrors()
 * try { await mutation.mutateAsync(payload) } catch (error) { if (!serverErrors.capture(error)) throw error }
 * <FieldError>{serverErrors.errors.name}</FieldError>
 * {serverErrors.offscreenSummary(['name']) && <p role="alert">…</p>}
 * ```
 */
export function useServerErrors() {
  const [state, setState] = useState<ServerErrorState>(NO_SERVER_ERRORS)

  /**
   * Keeps the messages of a `SpreeError`, replacing the previous ones.
   *
   * @returns `false` when the error is not from the API, for the caller to rethrow
   */
  const capture = useCallback((error: unknown): boolean => {
    const next = serverErrorStateFrom(error)
    if (!next) return false

    setState(next)
    return true
  }, [])

  /** Drops one field's message once the merchant changes that field. */
  const clear = useCallback((field: string) => {
    setState((previous) => withoutField(previous, field))
  }, [])

  const reset = useCallback(() => setState(NO_SERVER_ERRORS), [])

  /** @see offscreenSummaryOf */
  const offscreenSummary = useCallback(
    (shown: readonly string[]) => offscreenSummaryOf(state, shown),
    [state],
  )

  return { errors: state.errors, offscreenSummary, capture, clear, reset }
}

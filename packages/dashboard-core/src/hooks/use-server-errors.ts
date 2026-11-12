import { useCallback, useState } from 'react'
import type { FieldValues, UseFormSetError } from 'react-hook-form'
import { mapSpreeErrorsToForm } from '../lib/form-errors'

/** Server messages by field name, plus `root` for the failure summary. */
export type ServerErrors = Partial<Record<string, string>>

/**
 * The messages of a rejected save, as `mapSpreeErrorsToForm` would set them.
 *
 * @returns null when the error is not from the API
 */
export function readServerErrors(error: unknown): ServerErrors | null {
  const errors: ServerErrors = {}
  const setError = ((name: string, { message }: { message?: string }) => {
    errors[name] = message
  }) as UseFormSetError<FieldValues>

  return mapSpreeErrorsToForm(error, setError) ? errors : null
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
  const [errors, setErrors] = useState<ServerErrors>({})

  /**
   * Keeps the messages of a `SpreeError`, replacing the previous ones.
   *
   * @returns `false` when the error is not from the API, for the caller to rethrow
   */
  const capture = useCallback((error: unknown): boolean => {
    const next = readServerErrors(error)
    if (!next) return false

    setErrors(next)
    return true
  }, [])

  /** Drops one field's message once the merchant changes that field. */
  const clear = useCallback((field: string) => {
    setErrors((previous) => {
      if (!(field in previous)) return previous
      const { [field]: _cleared, ...rest } = previous
      return rest
    })
  }, [])

  const reset = useCallback(() => setErrors({}), [])

  /**
   * The summary, while a field this form does not render has a message: it
   * is the only place that message can show. A field on screen shows its own,
   * and a refusal with no field is already toasted by `useResourceMutation`.
   *
   * @param shown the field names this form renders
   */
  const offscreenSummary = useCallback(
    (shown: readonly string[]) =>
      Object.keys(errors).some((key) => key !== 'root' && !shown.includes(key))
        ? errors.root
        : undefined,
    [errors],
  )

  return { errors, offscreenSummary, capture, clear, reset }
}

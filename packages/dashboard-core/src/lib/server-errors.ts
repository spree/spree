import { SpreeError } from '@spree/admin-sdk'
import type { FieldValues, UseFormSetError } from 'react-hook-form'
import { mapSpreeErrorsToForm } from './form-errors'

/** Server messages by field name, plus `root` for the failure summary. */
export type ServerErrors = Partial<Record<string, string>>

/**
 * A rejected save as a plain-state form holds it: the messages, and every
 * field the server named (`base` and nested keys included), which tells a
 * form whether its summary is the only place a message can show.
 */
export interface ServerErrorState {
  errors: ServerErrors
  fields: string[]
}

export const NO_SERVER_ERRORS: ServerErrorState = { errors: {}, fields: [] }

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

/** @returns null when the error is not from the API */
export function serverErrorStateFrom(error: unknown): ServerErrorState | null {
  const errors = readServerErrors(error)
  if (!errors) return null

  const fields = error instanceof SpreeError && error.details ? Object.keys(error.details) : []
  return { errors, fields }
}

/**
 * The state once the merchant changes a field: its message goes, and so does
 * the field, so the summary stops counting a problem they have just edited.
 */
export function withoutField(state: ServerErrorState, field: string): ServerErrorState {
  if (!(field in state.errors) && !state.fields.includes(field)) return state

  const { [field]: _cleared, ...errors } = state.errors
  return { errors, fields: state.fields.filter((name) => name !== field) }
}

/**
 * The summary, while the server named a field this form does not render
 * (`base` included): it is the only place that message can show. A field on
 * screen shows its own, and a refusal with no field is already toasted by
 * `useResourceMutation`.
 *
 * @param shown the field names this form renders
 */
export function offscreenSummaryOf(
  state: ServerErrorState,
  shown: readonly string[],
): string | undefined {
  return state.fields.some((field) => !shown.includes(field)) ? state.errors.root : undefined
}

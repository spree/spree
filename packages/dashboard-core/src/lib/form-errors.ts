import type { ValidationErrorDetail } from '@spree/admin-sdk'
import { SpreeError } from '@spree/admin-sdk'
import i18n from 'i18next'
import type { FieldValues, Path, UseFormSetError } from 'react-hook-form'

/**
 * Text for one validation failure, in the admin's own language.
 *
 * The Admin API reports the Rails error `code` and the values the validation
 * interpolates, so the copy comes from the dashboard's locale files rather
 * than from a message the server resolved in the store's locale. Keys are
 * tried per-attribute first (`admin.validation.quantity.greater_than`), then
 * generally (`admin.validation.greater_than`); the server's `message` is the
 * fallback, which is what an extension's own error code gets.
 *
 * @param field the attribute the failure is attached to
 * @param entry the API's detail entry, or a plain string from an older payload
 * @returns the message to render
 */
function resolveDetailMessage(field: string, entry: string | ValidationErrorDetail): string {
  if (typeof entry === 'string') return entry

  const { code, message, ...interpolation } = entry
  if (code) {
    for (const key of [`admin.validation.${field}.${code}`, `admin.validation.${code}`]) {
      if (i18n.exists(key)) return i18n.t(key, interpolation)
    }
  }
  return message
}

/**
 * Map a thrown error from a Spree Admin API mutation onto a react-hook-form
 * instance. Two things happen on every call:
 *
 * 1. The server's top-level `error.message` (e.g. "Code can't be blank, Name
 *    can't be blank") is set on `formState.errors.root` so `<FormError>`
 *    always renders the full failure summary — even when individual fields
 *    aren't rendered (nested rules, useFieldArray rows, validations on
 *    associations).
 * 2. Per-key entries from `error.details` are also set as per-field errors
 *    for any key that names a top-level flat attribute (`code`, `name`,
 *    `expires_at`). Nested or dotted keys (`promotion_rules.base`, `rules`
 *    on a useFieldArray, `line_items.0.quantity`) only contribute to the
 *    root summary — we don't pretend to know which of those have rendered
 *    inputs, and "silent" is the worst outcome.
 *
 * Return value:
 *   - `true`  → the error was rendered into the form, the caller may suppress
 *               its toast
 *   - `false` → not a SpreeError (network / programming bug). Caller should
 *               log + toast as usual.
 *
 * Usage:
 *
 * ```ts
 * const create = useCreateThing()
 *
 * async function onSubmit(values: FormValues) {
 *   try {
 *     await create.mutateAsync(values)
 *     onSuccess()
 *   } catch (err) {
 *     if (!mapSpreeErrorsToForm(err, form.setError)) throw err
 *   }
 * }
 * ```
 *
 * Server response shape (from `Spree::Api::V3::ErrorHandler#render_validation_error`):
 *
 * ```json
 * { "error": {
 *     "code": "validation_error",
 *     "message": "Code can't be blank, Quantity must be greater than 0",
 *     "details": {
 *       "code": [{ "code": "blank", "message": "can't be blank" }],
 *       "quantity": [{ "code": "greater_than", "message": "must be greater than 0", "count": 0 }]
 *     }
 * } }
 * ```
 *
 * Each entry's `code` is translated from the dashboard's own locale files so
 * the admin reads their interface language rather than the store's; `message`
 * is the fallback for codes with no translation.
 *
 * `details` keys are AR attribute names. `<form-field>.base` is AR's
 * record-level errors collection on a nested association — we treat both
 * the bare `base` key and any `*.base` key as record-level and route them
 * to root.
 */
export function mapSpreeErrorsToForm<TFieldValues extends FieldValues>(
  error: unknown,
  setError: UseFormSetError<TFieldValues>,
): boolean {
  if (!(error instanceof SpreeError)) return false

  const { details, message } = error

  // Always seed the root error with the server's top-level message. Even
  // when details exist, the top-level message is the readable summary —
  // and it's the only place nested/association errors will reliably show.
  if (message) {
    setError('root' as Path<TFieldValues>, { type: 'server', message })
  }

  if (!details) return true

  // Per-field errors. Each detail value is `string[]` (one Rails error per
  // entry). Only top-level flat keys get set as per-field errors; nested
  // keys (`promotion_rules.base`, `rules`, `line_items.0.x`) stay on root.
  //
  // We're conservative on purpose: there's no way to know at this layer
  // whether a given path has a rendered input, so anything that smells
  // nested or associative falls back to the root summary that we already
  // set above. Silently dropping errors onto unrendered field paths is a
  // worse failure mode than redundant root messages.
  for (const [field, entries] of Object.entries(details)) {
    if (!entries?.length) continue
    if (!isRenderableFieldKey(field)) continue

    setError(field as Path<TFieldValues>, {
      type: 'server',
      message: entries.map((entry) => resolveDetailMessage(field, entry)).join(', '),
    })
  }

  return true
}

// `base` (bare) and `*.base` are AR's record-level errors. `*.<n>.*` is an
// association/collection index path. Anything with `.` is too risky to set
// as a top-level RHF path — it'd either create a phantom nested error or
// silently miss a rendered field. Stick to flat snake_case keys.
function isRenderableFieldKey(key: string): boolean {
  if (key === 'base') return false
  if (key.includes('.')) return false
  return true
}

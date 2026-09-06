import type { ValidationErrorDetail } from '@spree/admin-sdk'
import { SpreeError } from '@spree/admin-sdk'
import i18n from 'i18next'
import type { FieldValues, Path, UseFormSetError } from 'react-hook-form'

/**
 * Text for one validation failure, in the admin's own language.
 *
 * Server codes live under `admin.validation.codes`, apart from the client-side
 * keys the forms' own schemas read (`admin.validation.required`, …). The two
 * vocabularies overlap — Rails' `required` is a missing association, the
 * client's is an empty input — so they cannot share a namespace.
 *
 * The Admin API reports the Rails error `code` and the values the validation
 * interpolates, so the copy comes from the dashboard's locale files rather
 * than from a message the server resolved in the store's locale. Keys are
 * tried per-attribute first (`admin.validation.codes.quantity.greater_than`), then
 * generally (`admin.validation.codes.greater_than`); the server's `message` is the
 * fallback, which is what an extension's own error code gets.
 *
 * @param field the attribute the failure is attached to
 * @param entry the API's detail entry, or a plain string from an older payload
 * @returns the message to render
 */
function resolveDetailMessage(field: string, entry: string | ValidationErrorDetail): string {
  if (typeof entry === 'string') return entry

  const { code, message, specific, ...interpolation } = entry
  if (!code) return message

  // Per-attribute first: `admin.validation.codes.url.invalid` is written for this
  // one field and beats both the generic key and the server.
  const attributeKey = `admin.validation.codes.${field}.${code}`
  if (i18n.exists(attributeKey)) return i18n.t(attributeKey, interpolation)

  // `specific` means the model overrode the code's own wording with something
  // more useful — the webhook URL validation reports `invalid` but answers
  // "must be a valid http or https URL". Translating the code would throw
  // that away. The server decides this, because only it can compare against
  // the code's default in the locale the message was resolved in.
  if (specific) return message

  const genericKey = `admin.validation.codes.${code}`
  return i18n.exists(genericKey) ? i18n.t(genericKey, interpolation) : message
}

/**
 * Whether {@link resolveDetailMessage} will translate this entry rather than
 * fall back to the server's message.
 *
 * A per-attribute key is written for this one field and wins even over a
 * message the model worded itself; the generic key only applies when the
 * server did not mark the message as its own.
 */
function hasTranslation(field: string, entry: ValidationErrorDetail): boolean {
  if (i18n.exists(`admin.validation.codes.${field}.${entry.code}`)) return true
  if (entry.specific) return false
  return i18n.exists(`admin.validation.codes.${entry.code}`)
}

/**
 * The failure summary in the admin's own language: "Name can't be blank,
 * Quantity must be greater than 0", assembled from the translated entries and
 * the attribute names the dashboard already publishes.
 *
 * Returns null when any entry has no translation, in which case the server's
 * sentence is left alone rather than half-rebuilt.
 *
 * @param details the API's per-attribute failures
 * @returns the assembled summary, or null to keep the server's
 */
function translatedSummary(
  details: Record<string, Array<string | ValidationErrorDetail>>,
): string | null {
  const sentences: string[] = []

  for (const [field, entries] of Object.entries(details)) {
    for (const entry of entries ?? []) {
      // A plain string predates the coded shape and carries nothing to
      // translate; a missing code is a message added as bare text.
      if (typeof entry === 'string' || !entry.code) return null

      // Resolved exactly as the field error is, so the banner and the input
      // beneath it never disagree, and skipped only when that resolution
      // would fall through to the server's own sentence.
      if (!hasTranslation(field, entry)) return null

      sentences.push(`${attributeLabel(field)} ${resolveDetailMessage(field, entry)}`.trim())
    }
  }

  return sentences.length > 0 ? sentences.join(', ') : null
}

/**
 * Display name for an attribute, from the same keys the forms label their
 * inputs with. Falls back to the humanized attribute, which is what Rails
 * would have produced anyway.
 */
function attributeLabel(field: string): string {
  const key = `admin.fields.${field}.label`
  if (i18n.exists(key)) return i18n.t(key)
  if (field === 'base') return ''
  return field.replace(/_/g, ' ').replace(/^./, (c) => c.toUpperCase())
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

  // The summary banner is the line a merchant actually reads, so it follows
  // their interface language too. It is rebuilt from the translated entries
  // when every one of them translated; a single untranslated code means the
  // server's own sentence is still the more complete summary, and it stays.
  const summary = (details && translatedSummary(details)) || message
  if (summary) {
    setError('root' as Path<TFieldValues>, { type: 'server', message: summary })
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

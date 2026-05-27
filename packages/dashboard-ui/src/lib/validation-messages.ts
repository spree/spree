import i18n from 'i18next'

/**
 * Lazy "<Field> is required" message for Zod v4 schemas. Wrap in `{ error: ... }`
 * so the message is resolved per validation (not at module load) — keeps the
 * literal out of the schema and lets locale changes pick up.
 *
 * ```ts
 * z.string().min(1, { error: requiredMessage('name') })
 * z.string().min(1, { error: requiredMessage('payment_method.type') })
 * ```
 *
 * `field` is a dot-path under `admin.fields.*` resolving to a `.label` key —
 * `'name'` → `admin.fields.name.label`, `'payment_method.type'` →
 * `admin.fields.payment_method.type.label`.
 */
export function requiredMessage(field: string): () => string {
  return () => i18n.t('admin.validation.required', { field: i18n.t(`admin.fields.${field}.label`) })
}

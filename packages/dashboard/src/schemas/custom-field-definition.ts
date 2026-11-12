import type {
  CustomFieldDefinition,
  CustomFieldDefinitionCreateParams,
  CustomFieldDefinitionUpdateParams,
  CustomFieldValidationsParams,
} from '@spree/admin-sdk'
import { formatStoreDate, formatStoreDateTime, i18n } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

// Mirrors `Spree::CustomField::FIELD_TYPE_TOKENS` on the backend. Keep in sync
// with the typelized `field_type` union on `CustomFieldDefinition`. Labels
// come from i18n via `fieldTypeLabel()` below.
export const FIELD_TYPES = [
  'short_text',
  'long_text',
  'rich_text',
  'number',
  'boolean',
  'json',
  'date',
  'date_time',
  'choice',
] as const

export type FieldType = (typeof FIELD_TYPES)[number]

/** Field types that may set `searchable: true` (mirrors backend validation). */
export const SEARCHABLE_FIELD_TYPES = [
  'short_text',
  'long_text',
  'number',
  'date',
  'date_time',
  'choice',
] as const

/**
 * Field types that may set `sortable: true` (mirrors backend validation). A
 * choice field that allows several values cannot sort.
 */
export const SORTABLE_FIELD_TYPES = ['short_text', 'number', 'date', 'date_time', 'choice'] as const

export function fieldTypeSupportsSearchable(fieldType: string): boolean {
  return (SEARCHABLE_FIELD_TYPES as readonly string[]).includes(fieldType)
}

export function fieldTypeSupportsSortable(fieldType: string): boolean {
  return (SORTABLE_FIELD_TYPES as readonly string[]).includes(fieldType)
}

/** What a field type's `min` / `max` rules bound, or null when it takes none. */
export type BoundKind = 'length' | 'number' | 'date' | 'date_time'

export function fieldTypeBoundKind(fieldType: string): BoundKind | null {
  switch (fieldType) {
    case 'short_text':
    case 'long_text':
      return 'length'
    case 'number':
    case 'date':
    case 'date_time':
      return fieldType
    default:
      return null
  }
}

export function fieldTypeLabel(value: string): string {
  return i18n.t(`admin.fields.custom_field_definition.field_type.options.${value}`, {
    defaultValue: value,
  })
}

// Owner types whose values merchants can edit in the dashboard. The server
// allows more (see `Spree.custom_fields.enabled_resources`); the definition
// picker lists those under "Through the API only", since nothing here edits
// them. A type gains a place here when a screen gets the custom fields card.
export const DEFAULT_RESOURCE_TYPES = [
  'product',
  'variant',
  'order',
  'customer',
  'category',
  'collection',
  'option_type',
  'seller',
  'promotion',
  'gift_card',
  'store_credit',
  'stock_transfer',
  'purchase_order',
  'company',
  'payment_method',
  'delivery_method',
  'tax_rate',
  'product_type',
  'media',
  'store',
] as const

export type ResourceType = (typeof DEFAULT_RESOURCE_TYPES)[number] | (string & {})

/**
 * @param fallback shown for an owner the i18n bundle doesn't enumerate
 *   (plugin-defined resource types) — the server's name for it, when known;
 *   otherwise the value is humanized.
 */
export function resourceTypeLabel(value: string, fallback?: string): string {
  return i18n.t(`admin.fields.custom_field_definition.resource_type.options.${value}`, {
    defaultValue:
      fallback ?? value.replace(/_/g, ' ').replace(/^\w/, (letter) => letter.toUpperCase()),
  })
}

// Bounds stay strings in the form ('' = no bound); the server normalizes them.
const validationsSchema = z.object({
  required: z.boolean(),
  min: z.string(),
  max: z.string(),
  multiple: z.boolean(),
  choices: z.array(z.object({ value: z.string(), label: z.string() })),
})

export const customFieldDefinitionSchema = z
  .object({
    label: z.string().min(1, { error: requiredMessage('custom_field_definition.label') }),
    namespace: z.string().min(1, { error: requiredMessage('custom_field_definition.namespace') }),
    key: z
      .string()
      .min(1, { error: requiredMessage('custom_field_definition.key') })
      .regex(/^[a-z0-9_]+$/i, {
        error: () => i18n.t('admin.fields.custom_field_definition.key.invalid_format'),
      }),
    field_type: z.enum(FIELD_TYPES),
    resource_type: z
      .string()
      .min(1, { error: requiredMessage('custom_field_definition.resource_type') }),
    storefront_visible: z.boolean(),
    searchable: z.boolean(),
    sortable: z.boolean(),
    validations: validationsSchema,
  })
  .superRefine((values, ctx) => {
    if (values.field_type !== 'choice') return

    const choiceValues = values.validations.choices.map((choice) => choice.value.trim())
    if (choiceValues.length === 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['validations', 'choices'],
        message: i18n.t('admin.fields.custom_field_definition.validations.choices.required'),
      })
    }
    choiceValues.forEach((value, index) => {
      const message = !value
        ? i18n.t('admin.fields.custom_field_definition.validations.choices.value_required')
        : choiceValues.indexOf(value) !== index
          ? i18n.t('admin.fields.custom_field_definition.validations.choices.duplicate')
          : null
      if (message) {
        ctx.addIssue({ code: 'custom', path: ['validations', 'choices', index, 'value'], message })
      }
    })
  })

export type CustomFieldDefinitionFormValues = z.infer<typeof customFieldDefinitionSchema>

export const CUSTOM_FIELD_DEFINITION_DEFAULTS: CustomFieldDefinitionFormValues = {
  label: '',
  namespace: 'custom',
  key: '',
  field_type: 'short_text',
  resource_type: 'product',
  storefront_visible: false,
  searchable: false,
  sortable: false,
  validations: { required: false, min: '', max: '', multiple: false, choices: [] },
}

export function customFieldDefinitionToFormValues(
  definition: CustomFieldDefinition,
): CustomFieldDefinitionFormValues {
  const { required, min, max, multiple, choices } = definition.validations
  return {
    label: definition.label,
    namespace: definition.namespace,
    key: definition.key,
    field_type: definition.field_type,
    resource_type: definition.resource_type,
    storefront_visible: definition.storefront_visible,
    searchable: definition.searchable,
    sortable: definition.sortable,
    validations: {
      required,
      min: min == null ? '' : String(min),
      max: max == null ? '' : String(max),
      multiple,
      choices: choices.map((choice) => ({ ...choice })),
    },
  }
}

// Only the rules that apply to the field type; null when none are set.
function validationsToParams(
  values: CustomFieldDefinitionFormValues,
): CustomFieldValidationsParams | null {
  const { required, min, max, multiple, choices } = values.validations
  const rules: CustomFieldValidationsParams = {}
  if (required) rules.required = true
  if (fieldTypeBoundKind(values.field_type)) {
    if (min.trim()) rules.min = min.trim()
    if (max.trim()) rules.max = max.trim()
  }
  if (values.field_type === 'choice') {
    rules.choices = choices.map((choice) => ({
      value: choice.value.trim(),
      label: choice.label.trim() || undefined,
    }))
    if (multiple) rules.multiple = true
  }
  return Object.keys(rules).length > 0 ? rules : null
}

/** No value to store: the API removes the field rather than saving it. */
export function isBlank(value: unknown) {
  return (
    value == null ||
    (typeof value === 'string' && value.trim() === '') ||
    (Array.isArray(value) && value.length === 0)
  )
}

/** A choice's label; a value whose choice was since removed shows raw, as the server keeps it. */
export function choiceLabel(definition: CustomFieldDefinition, choice: unknown): string {
  return (
    definition.validations?.choices.find((option) => option.value === String(choice))?.label ??
    String(choice)
  )
}

/** A stored value as read-only text, in the store's time zone. */
export function formatCustomFieldValue(
  value: unknown,
  definition: CustomFieldDefinition,
  timezone: string,
): string {
  const empty = i18n.t('admin.common.empty_value')
  if (isBlank(value)) return empty

  switch (definition.field_type) {
    case 'boolean':
      return i18n.t(value ? 'admin.common.yes' : 'admin.common.no')
    case 'rich_text': {
      // Plain-text preview of HTML. DOMParser handles nested/malformed tags
      // correctly — a single-pass regex strip can leak tags via patterns like
      // `<scr<script>ipt>` (CodeQL js/incomplete-multi-character-sanitization).
      const text = new DOMParser().parseFromString(String(value), 'text/html').body.textContent
      return text?.trim() || empty
    }
    case 'json':
      return typeof value === 'string' ? value : JSON.stringify(value)
    case 'date':
      // A calendar day: format it as written, never shifted into a zone.
      return formatStoreDate(`${value}T00:00:00Z`, 'UTC')
    case 'date_time':
      return formatStoreDateTime(String(value), timezone)
    case 'choice':
      return (Array.isArray(value) ? value : [value])
        .map((choice) => choiceLabel(definition, choice))
        .join(', ')
    default:
      return String(value)
  }
}

/**
 * Checks a value against its definition's rules, as the server does when it
 * is written, so a form can show the problem before saving. `required` is
 * checked only when asked: the server leaves it to the forms, and a blank
 * field is not an error until the merchant tries to save.
 */
export function customFieldValueError(
  definition: CustomFieldDefinition,
  value: unknown,
  { checkRequired = false }: { checkRequired?: boolean } = {},
): string | null {
  const rules = definition.validations
  if (!rules) return null
  const message = (key: string, options: Record<string, unknown> = {}) =>
    i18n.t(`admin.components.custom_fields.errors.${key}`, options)

  if (isBlank(value)) return checkRequired && rules.required ? message('required') : null

  const { min, max } = rules
  switch (fieldTypeBoundKind(definition.field_type)) {
    case 'length': {
      // By characters, as the server counts them, not UTF-16 code units.
      const length = [...String(value).trim()].length
      if (min != null && length < Number(min)) return message('too_short', { count: Number(min) })
      if (max != null && length > Number(max)) return message('too_long', { count: Number(max) })
      return null
    }
    case 'number': {
      const number = Number(value)
      if (Number.isNaN(number)) return null
      if (min != null && number < Number(min)) return message('less_than_min', { min })
      if (max != null && number > Number(max)) return message('greater_than_max', { max })
      return null
    }
    case 'date':
    case 'date_time': {
      // Dates compare as ISO text, date-times as instants.
      const at = (iso: string | number) =>
        definition.field_type === 'date' ? String(iso) : Date.parse(String(iso))
      if (min != null && at(String(value)) < at(min)) return message('before_min', { min })
      if (max != null && at(String(value)) > at(max)) return message('after_max', { max })
      return null
    }
  }

  if (definition.field_type === 'choice') {
    const offered = rules.choices.map((choice) => choice.value)
    const missing = (Array.isArray(value) ? value : [value]).find(
      (chosen) => !offered.includes(String(chosen)),
    )
    if (missing !== undefined) return message('choice_not_offered', { value: String(missing) })
  }
  return null
}

export function customFieldDefinitionValuesToCreateParams(
  v: CustomFieldDefinitionFormValues,
): CustomFieldDefinitionCreateParams {
  return {
    label: v.label,
    namespace: v.namespace,
    key: v.key,
    field_type: v.field_type,
    resource_type: v.resource_type,
    storefront_visible: v.storefront_visible,
    searchable: v.searchable,
    sortable: v.sortable,
    validations: validationsToParams(v),
  }
}

export function customFieldDefinitionValuesToUpdateParams(
  v: CustomFieldDefinitionFormValues,
): CustomFieldDefinitionUpdateParams {
  // `resource_type` and `field_type` are fixed once a definition exists; the
  // API refuses a change with a 422.
  return {
    label: v.label,
    namespace: v.namespace,
    key: v.key,
    storefront_visible: v.storefront_visible,
    searchable: v.searchable,
    sortable: v.sortable,
    validations: validationsToParams(v),
  }
}

import type {
  CustomFieldDefinitionCreateParams,
  CustomFieldDefinitionUpdateParams,
} from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'
import { i18n } from '@/lib/i18n'

// Mirrors `Spree::Metafield::FIELD_TYPE_TOKENS` on the backend. Keep in sync
// with the typelized `field_type` union on `CustomFieldDefinition`. Labels
// come from i18n via `fieldTypeLabel()` below.
export const FIELD_TYPES = [
  'short_text',
  'long_text',
  'rich_text',
  'number',
  'boolean',
  'json',
] as const

export type FieldType = (typeof FIELD_TYPES)[number]

export function fieldTypeLabel(value: string): string {
  return i18n.t(`admin.fields.custom_field_definition.field_type.options.${value}`, {
    defaultValue: value,
  })
}

// Owner types that have a first-class admin UI. The server allows more (see
// `Spree.metafields.enabled_resources`); these are the ones admins can pick
// when defining a field. Extending this is a one-line add — the API already
// accepts any resource type registered in core.
export const DEFAULT_RESOURCE_TYPES = [
  'Spree::Product',
  'Spree::Variant',
  'Spree::Order',
  'Spree::User',
  'Spree::Category',
  'Spree::OptionType',
] as const

export type ResourceType = (typeof DEFAULT_RESOURCE_TYPES)[number] | (string & {})

export function resourceTypeLabel(value: string): string {
  // `nsSeparator: false` because resource type keys contain `::`, which
  // i18next would otherwise parse as a namespace separator and miss the
  // lookup. `defaultValue` strips the `Spree::` prefix for any owner the
  // i18n bundle doesn't enumerate (plugin-defined resource types).
  return i18n.t(`admin.fields.custom_field_definition.resource_type.options.${value}`, {
    nsSeparator: false,
    defaultValue: value.replace(/^Spree::/, ''),
  })
}

export const customFieldDefinitionSchema = z.object({
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
})

export type CustomFieldDefinitionFormValues = z.infer<typeof customFieldDefinitionSchema>

export const CUSTOM_FIELD_DEFINITION_DEFAULTS: CustomFieldDefinitionFormValues = {
  label: '',
  namespace: 'custom',
  key: '',
  field_type: 'short_text',
  resource_type: 'Spree::Product',
  storefront_visible: false,
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
  }
}

export function customFieldDefinitionValuesToUpdateParams(
  v: CustomFieldDefinitionFormValues,
): CustomFieldDefinitionUpdateParams {
  // `resource_type` and `field_type` are intentionally omitted — changing
  // either would orphan or invalidate stored values. `Spree::Metafield` rows
  // serialize via their own STI subclass (set from the definition at write
  // time), so flipping `field_type` post-hoc would leave existing values
  // misinterpreted by the UI. The controller still accepts these fields;
  // the UI just doesn't offer them as editable.
  return {
    label: v.label,
    namespace: v.namespace,
    key: v.key,
    storefront_visible: v.storefront_visible,
  }
}

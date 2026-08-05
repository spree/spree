import type { Collection, CollectionRuleParam, CollectionSortOrder } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'
import { customFieldFormSchema } from './product'

/**
 * Canonical values only — labels are resolved at render time via
 * {@link sortOrderLabelKey}. The space-separated form is the server's own
 * vocabulary (Spree::Collection::SORT_ORDERS) and is what goes back on the
 * wire unchanged.
 */
export const COLLECTION_SORT_ORDERS = [
  'manual',
  'best_selling',
  'price asc',
  'price desc',
  'available_on desc',
  'available_on asc',
  'name asc',
  'name desc',
] as const satisfies ReadonlyArray<CollectionSortOrder>

/**
 * Locale key for a sort order's label. The server vocabulary is
 * space-separated (`price asc`) while the locale keys are underscored, so the
 * mapping lives here rather than being re-derived at each call site.
 */
export function sortOrderLabelKey(value: string) {
  return `admin.collections.sort_orders.${value.replaceAll(' ', '_')}`
}

function isKnownSortOrder(value: string | null | undefined): value is CollectionSortOrder {
  return COLLECTION_SORT_ORDERS.includes(value as CollectionSortOrder)
}

/**
 * Wire shorthand for the rule kind, e.g. `tag`. The authoritative list comes
 * from `GET /collection_rules/types` (registry-driven, so plugins appear too),
 * which is why this is an open string rather than an enum — a rule kind this
 * build doesn't know must still round-trip instead of failing validation.
 */
const DEFAULT_RULE_TYPE = 'tag'

/**
 * `Spree::CollectionRules::AvailableOn` -> `available_on`. The API serializes
 * rules with their STI class name but accepts (and advertises) the shorthand,
 * so normalize on the way in.
 */
function ruleTypeShorthand(type: string) {
  const leaf = type.split('::').pop() ?? type
  return leaf.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase()
}

export const COLLECTION_RULE_MATCH_POLICIES = [
  'is_equal_to',
  'is_not_equal_to',
  'contains',
  'does_not_contain',
] as const

export const COLLECTION_RULES_MATCH_POLICIES = ['all', 'any'] as const

// Each image field is a small state machine: untouched (omit on save),
// uploaded (send signed_id), or cleared (send null to purge).
const imageFields = {
  image_signed_id: z.string().nullable(),
  image_preview_url: z.string().nullable(),
  image_cleared: z.boolean(),
  square_image_signed_id: z.string().nullable(),
  square_image_preview_url: z.string().nullable(),
  square_image_cleared: z.boolean(),
}

const collectionRuleSchema = z.object({
  /** Prefixed `crule_` id. Absent on a rule the merchant just added. */
  id: z.string().optional(),
  type: z.string().min(1),
  value: z.string().min(1, { error: requiredMessage('value') }),
  match_policy: z.enum(COLLECTION_RULE_MATCH_POLICIES),
})

export type CollectionRuleFormValues = z.infer<typeof collectionRuleSchema>

export const collectionFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  description: z.string(),
  permalink: z.string(),
  meta_title: z.string(),
  meta_description: z.string(),
  sort_order: z.enum(COLLECTION_SORT_ORDERS),
  automatic: z.boolean(),
  rules_match_policy: z.enum(COLLECTION_RULES_MATCH_POLICIES),
  rules: z.array(collectionRuleSchema),
  custom_fields: z.array(customFieldFormSchema).optional(),
  ...imageFields,
})

export type CollectionFormValues = z.infer<typeof collectionFormSchema>

const IMAGE_DEFAULTS = {
  image_signed_id: null,
  image_preview_url: null,
  image_cleared: false,
  square_image_signed_id: null,
  square_image_preview_url: null,
  square_image_cleared: false,
} satisfies Partial<CollectionFormValues>

export const COLLECTION_DEFAULTS: CollectionFormValues = {
  name: '',
  description: '',
  permalink: '',
  meta_title: '',
  meta_description: '',
  sort_order: 'manual',
  automatic: false,
  rules_match_policy: 'all',
  rules: [],
  custom_fields: [],
  ...IMAGE_DEFAULTS,
}

/** A blank rule row, used when the merchant adds one to an automatic collection. */
export function blankCollectionRule(): CollectionRuleFormValues {
  return { type: DEFAULT_RULE_TYPE, value: '', match_policy: 'is_equal_to' }
}

/** Hydrate the form from an API collection row. */
export function collectionToForm(collection: Collection): CollectionFormValues {
  return {
    name: collection.name ?? '',
    description: collection.description_html ?? '',
    permalink: collection.permalink ?? '',
    meta_title: collection.meta_title ?? '',
    meta_description: collection.meta_description ?? '',
    // Fall back rather than trust the column: a value this build doesn't know
    // (an older/newer server) would otherwise fail the form's own validation
    // and block every save, including edits that never touch the sort.
    sort_order: isKnownSortOrder(collection.sort_order) ? collection.sort_order : 'manual',
    automatic: collection.automatic ?? false,
    rules_match_policy: collection.rules_match_policy === 'any' ? 'any' : 'all',
    rules:
      collection.rules?.map((rule) => ({
        id: rule.id,
        type: ruleTypeShorthand(rule.type),
        value: rule.value ?? '',
        match_policy: rule.match_policy as CollectionRuleFormValues['match_policy'],
      })) ?? [],
    custom_fields:
      collection.custom_fields?.map((cf) => ({
        id: cf.id,
        custom_field_definition_id: cf.custom_field_definition_id,
        value: cf.value,
      })) ?? [],
    ...IMAGE_DEFAULTS,
  }
}

/** Map the form to the create/update API params (drops frontend-only fields). */
export function collectionToParams(values: CollectionFormValues) {
  return {
    name: values.name,
    description: values.description,
    permalink: values.permalink,
    meta_title: values.meta_title,
    meta_description: values.meta_description,
    sort_order: values.sort_order,
    automatic: values.automatic,
    rules_match_policy: values.rules_match_policy,
    // `rules` is a sync setter server-side: the array IS the desired rule set,
    // so omitted rules are deleted. Only send it for automatic collections —
    // a manual one has no rules to express, and sending [] would wipe the rules
    // of a collection the merchant just toggled off (they come back on re-enable).
    ...(values.automatic ? { rules: values.rules as CollectionRuleParam[] } : {}),
    ...(values.custom_fields && values.custom_fields.length > 0
      ? { custom_fields: values.custom_fields }
      : {}),
    ...imageParam('image', values.image_signed_id, values.image_cleared),
    ...imageParam('square_image', values.square_image_signed_id, values.square_image_cleared),
  }
}

// Three-state mapping: a fresh upload sends the signed_id, an explicit clear
// sends null (purges the attachment), and an untouched field is omitted.
function imageParam(key: 'image' | 'square_image', signedId: string | null, cleared: boolean) {
  if (signedId) return { [key]: signedId }
  if (cleared) return { [key]: null }
  return {}
}

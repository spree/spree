import type { Collection, CollectionRuleParams } from '@spree/admin-sdk'
import {
  COLLECTION_RULE_MATCH_POLICIES,
  COLLECTION_SORT_ORDERS,
  type CollectionSortOrder,
  isDecimalString,
  MATCH_POLICIES,
} from '@spree/core'
import { customFieldFormSchema, signedIdParam } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { z } from 'zod/v4'
import type { ProductMembershipStagingValue } from '../components/spree/product-membership-staging'

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
 * Narrows a server-supplied match policy to one this build knows. The rule
 * registry is server-driven, so an unrecognized policy falls back to the
 * default rather than rendering an empty Select and failing validation on save.
 */
function knownMatchPolicy(value: string | null): CollectionRuleFormValues['match_policy'] {
  const policies: readonly string[] = COLLECTION_RULE_MATCH_POLICIES
  return policies.includes(value ?? '')
    ? (value as CollectionRuleFormValues['match_policy'])
    : 'is_equal_to'
}

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

/** Built-in rule types whose value is an amount. */
const AMOUNT_RULE_TYPES = ['price']

const collectionRuleFields = z.object({
  /** Prefixed `crule_` id. Absent on a rule the merchant just added. */
  id: z.string().optional(),
  type: z.string().min(1),
  value: z.string(),
  match_policy: z.enum(COLLECTION_RULE_MATCH_POLICIES),
  /** Price and sale rules: the currency they evaluate in; null is the store's default. */
  currency: z.string().nullable(),
  /** Per-type settings, e.g. `include_descendants`, `custom_field_definition_id`. */
  preferences: z.record(z.string(), z.unknown()),
})

/**
 * @param valuelessTypes rule types the types endpoint lists with
 *   `value_required: false` (in stock), which take no value; null while
 *   the types load, when no rule needs one
 */
function collectionRuleSchema(valuelessTypes: readonly string[] | null) {
  return collectionRuleFields.superRefine((rule, ctx) => {
    if (valuelessTypes?.includes(rule.type)) return
    if (rule.value.trim() === '') {
      if (valuelessTypes === null) return
      ctx.addIssue({
        code: 'custom',
        path: ['value'],
        message: requiredMessage('collection_rule.value')(),
      })
    } else if (AMOUNT_RULE_TYPES.includes(rule.type) && !isDecimalString(rule.value.trim())) {
      ctx.addIssue({
        code: 'custom',
        path: ['value'],
        message: i18n.t('admin.collections.rules.amount_invalid'),
      })
    }
  })
}

export type CollectionRuleFormValues = z.infer<typeof collectionRuleFields>

/**
 * The collection form schema. Which rule types take no value comes from the
 * types endpoint, so the caller passes it in (see `useCollectionFormResolver`).
 */
export const collectionFormSchema = (valuelessTypes: readonly string[] | null = []) =>
  z.object({
    /**
     * Staged product membership, applied on Save through the nested products
     * endpoints. Deliberately opaque: it holds SDK `Product` records so a
     * staged addition can render before it exists server-side, and RHF's
     * `Path<T>` must not walk that object graph (see the note on
     * `RuleEmbedRecord` in schemas/price-list.ts). Never sent to the API —
     * `collectionToParams` drops it.
     */
    staged_products: z.custom<ProductMembershipStagingValue>(() => true),
    name: z.string().min(1, { error: requiredMessage('name') }),
    description: z.string(),
    permalink: z.string(),
    meta_title: z.string(),
    meta_description: z.string(),
    sort_order: z.enum(COLLECTION_SORT_ORDERS),
    rules_match_policy: z.enum(MATCH_POLICIES),
    rules: z.array(collectionRuleSchema(valuelessTypes)),
    /**
     * The channels the collection is published on — a sync set. Null on a new
     * collection until the Publishing card seeds it, so a create that never
     * loaded channels still publishes everywhere (the server's default).
     */
    publications: z
      .array(
        z.object({
          channel_id: z.string(),
          published_at: z.string().nullable(),
          unpublished_at: z.string().nullable(),
        }),
      )
      .nullable(),
    custom_fields: z.array(customFieldFormSchema).optional(),
    ...imageFields,
  })

export type CollectionFormValues = z.infer<ReturnType<typeof collectionFormSchema>>

const IMAGE_DEFAULTS = {
  image_signed_id: null,
  image_preview_url: null,
  image_cleared: false,
  square_image_signed_id: null,
  square_image_preview_url: null,
  square_image_cleared: false,
} satisfies Partial<CollectionFormValues>

export const COLLECTION_DEFAULTS: CollectionFormValues = {
  staged_products: { adds: [], removes: [] },
  name: '',
  description: '',
  permalink: '',
  meta_title: '',
  meta_description: '',
  sort_order: 'manual',
  rules_match_policy: 'all',
  rules: [],
  publications: [],
  custom_fields: [],
  ...IMAGE_DEFAULTS,
}

/** A blank rule row. */
export function blankCollectionRule(): CollectionRuleFormValues {
  return {
    type: DEFAULT_RULE_TYPE,
    value: '',
    match_policy: 'is_equal_to',
    currency: null,
    preferences: {},
  }
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
    rules_match_policy: collection.rules_match_policy === 'any' ? 'any' : 'all',
    rules:
      collection.rules?.map((rule) => ({
        id: rule.id,
        type: rule.type,
        value: rule.value ?? '',
        match_policy: knownMatchPolicy(rule.match_policy),
        currency: rule.currency ?? null,
        preferences: rule.preferences ?? {},
      })) ?? [],
    publications:
      collection.publications?.map((publication) => ({
        channel_id: publication.channel_id,
        published_at: publication.published_at,
        unpublished_at: publication.unpublished_at,
      })) ?? [],
    custom_fields:
      collection.custom_fields?.map((cf) => ({
        id: cf.id,
        custom_field_definition_id: cf.custom_field_definition_id,
        value: cf.value,
      })) ?? [],
    // Membership starts unstaged on every hydrate — a reset re-baselines the
    // form, and anything staged has either been flushed or discarded.
    staged_products: { adds: [], removes: [] },
    ...IMAGE_DEFAULTS,
  }
}

/** Map the form to the create/update API params (drops frontend-only fields). */
export function collectionToParams(values: CollectionFormValues) {
  return {
    name: values.name,
    // HTML in, HTML stored. The API reads it back as plain `description`
    // plus `description_html`.
    description: values.description,
    permalink: values.permalink,
    meta_title: values.meta_title,
    meta_description: values.meta_description,
    sort_order: values.sort_order,
    rules_match_policy: values.rules_match_policy,
    // `rules` and `publications` are sync setters server-side: each array IS
    // the desired set, so an omitted rule or channel is removed. A collection
    // with no rules is curated by hand only.
    rules: values.rules as CollectionRuleParams[],
    ...(values.publications ? { publications: values.publications } : {}),
    ...(values.custom_fields && values.custom_fields.length > 0
      ? { custom_fields: values.custom_fields }
      : {}),
    ...signedIdParam('image', values.image_signed_id, values.image_cleared),
    ...signedIdParam('square_image', values.square_image_signed_id, values.square_image_cleared),
  }
}

import type {
  Channel,
  Customer,
  CustomerGroup,
  Market,
  PreferenceField,
  PriceListCreateParams,
  PriceListUpdateParams,
  PriceRule,
} from '@spree/admin-sdk'
import { blankToNull, defaultPreferences } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { z } from 'zod/v4'

export const MATCH_POLICIES = ['all', 'any'] as const
export type MatchPolicy = (typeof MATCH_POLICIES)[number]

/**
 * Form-state row for a price rule. Carries the editor's display fields
 * (`label`, `description`, `preference_schema`) alongside the payload
 * fields the API consumes (`type`, `preferences`, optional `id`). Closely
 * mirrors `PromotionRuleFormDraft` so the editor patterns are 1:1.
 */
export interface PriceRuleFormDraft {
  /** Stable client-side id used as a React key while the row has no server id. */
  _localId: string
  /** Present once the row has been persisted. */
  id?: string
  /** Wire shorthand — `volume_rule`, `market_rule`, etc. */
  type: string
  label: string
  description?: string | null
  preference_schema: PreferenceField[]
  preferences: Record<string, unknown>
  /**
   * Display-only embeds the per-rule editors set when the user picks
   * records via autocomplete. Used by `RuleSummary` so the row preview
   * reads "Customer groups: VIPs, Wholesale" instead of "cg_…". Never
   * sent to the API — `priceListValuesToParams` strips them.
   */
  customers?: Customer[]
  customer_groups?: CustomerGroup[]
  markets?: Market[]
  channels?: Channel[]
}

const priceRuleDraftSchema: z.ZodType<PriceRuleFormDraft> = z.object({
  _localId: z.string(),
  id: z.string().optional(),
  type: z.string().min(1),
  label: z.string(),
  description: z.string().nullable().optional(),
  preference_schema: z.array(z.any()).default([]),
  preferences: z.record(z.string(), z.unknown()).default({}),
  customers: z.array(z.any()).optional(),
  customer_groups: z.array(z.any()).optional(),
  markets: z.array(z.any()).optional(),
  channels: z.array(z.any()).optional(),
}) as unknown as z.ZodType<PriceRuleFormDraft>

export const priceListFormSchema = z
  .object({
    name: z
      .string()
      .trim()
      .min(1, { error: requiredMessage('price_list.name') }),
    description: z.string().trim().optional(),
    starts_at: z.string().optional().nullable(),
    ends_at: z.string().optional().nullable(),
    match_policy: z.enum(MATCH_POLICIES).default('all'),
    rules: z.array(priceRuleDraftSchema).default([]),
    /**
     * Prefixed product ids in the list. The server reconciles this set
     * on every PATCH — adds placeholder prices for new ids, drops prices
     * for removed ones — so the form ships the full desired set.
     */
    product_ids: z.array(z.string()).default([]),
  })
  .refine(
    (v) => {
      if (!v.starts_at || !v.ends_at) return true
      return new Date(v.starts_at) < new Date(v.ends_at)
    },
    {
      path: ['ends_at'],
      error: () => i18n.t('admin.products.price_lists.validation.ends_after_starts'),
    },
  )

export type PriceListFormValues = z.infer<typeof priceListFormSchema>

export const PRICE_LIST_DEFAULTS: PriceListFormValues = {
  name: '',
  description: '',
  starts_at: null,
  ends_at: null,
  match_policy: 'all',
  rules: [],
  product_ids: [],
}

export function priceListValuesToParams(
  v: PriceListFormValues,
): PriceListCreateParams & PriceListUpdateParams {
  return {
    name: v.name,
    description: blankToNull(v.description),
    starts_at: v.starts_at || null,
    ends_at: v.ends_at || null,
    match_policy: v.match_policy,
    rules: v.rules.map(ruleDraftToPayload),
    product_ids: v.product_ids,
  }
}

let nextLocalId = 0
function newLocalId(): string {
  nextLocalId += 1
  return `pl-rule-${nextLocalId}`
}

/** Materializes a draft from an existing server-side rule. */
export function ruleDraftFromRule(rule: PriceRule): PriceRuleFormDraft {
  return {
    _localId: rule.id,
    id: rule.id,
    type: rule.type,
    label: rule.label,
    description: rule.description,
    preference_schema: rule.preference_schema,
    preferences: rule.preferences,
    customers: rule.customers ?? undefined,
    customer_groups: rule.customer_groups ?? undefined,
    markets: rule.markets ?? undefined,
    channels: rule.channels ?? undefined,
  }
}

/** Materializes a fresh draft from a registry type definition. */
export function ruleDraftFromType(type: {
  type: string
  label: string
  description?: string | null
  preference_schema: PreferenceField[]
}): PriceRuleFormDraft {
  return {
    _localId: newLocalId(),
    type: type.type,
    label: type.label,
    description: type.description ?? null,
    preference_schema: type.preference_schema,
    preferences: defaultPreferences(type.preference_schema),
  }
}

/** Strips display-only fields before sending to the API. */
export function ruleDraftToPayload(draft: PriceRuleFormDraft) {
  return {
    id: draft.id,
    type: draft.type,
    preferences: draft.preferences,
  }
}

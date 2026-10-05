import type {
  PreferenceField,
  PriceList,
  PriceListCreateParams,
  PriceListUpdateParams,
  PriceRule,
} from '@spree/admin-sdk'
import { blankToNull, defaultPreferences } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { z } from 'zod/v4'
import type { ProductMembershipStagingValue } from '../components/spree/product-membership-staging'

export const MATCH_POLICIES = ['all', 'any'] as const
export type MatchPolicy = (typeof MATCH_POLICIES)[number]

/**
 * How a list produces prices. `fixed` prices only what it holds explicit
 * rows for — every list that existed before automatic pricing. `automatic`
 * derives from base prices by a percentage, with explicit rows still
 * winning per variant.
 */
export const PRICING_MODES = ['fixed', 'automatic'] as const
export type PricingMode = (typeof PRICING_MODES)[number]

/**
 * Stored signed (negative = discount), but edited as magnitude + direction:
 * a merchant thinks "15% off", not "-15".
 */
export const ADJUSTMENT_DIRECTIONS = ['decrease', 'increase'] as const

/**
 * How many quantity tiers one ladder may hold — bands on a list's percentage
 * or breaks on a variant's price rows. Mirrors the server's cap, so the
 * editor stops offering "add" rather than letting a save be refused
 * (docs/plans/6.0-volume-pricing.md).
 */
export const MAXIMUM_QUANTITY_TIERS = 10
export type AdjustmentDirection = (typeof ADJUSTMENT_DIRECTIONS)[number]

/**
 * One quantity band as the form edits it: strings, so an unusable entry can
 * be reported rather than silently coerced. Declared rather than inferred —
 * the validators below take it as a parameter, and inferring it from the
 * schemas they belong to would make those schemas' types circular
 * (docs/plans/6.0-volume-pricing.md).
 */
export interface AdjustmentTierValue {
  min_quantity: string
  percentage: string
}

/**
 * Quantity bands on a list's percentage: "10% from ten, 20% from fifty" as
 * one ladder. Shared by the catalog's pricing card and the standalone price
 * list page.
 */
export const adjustmentTierSchema = z
  .array(z.object({ min_quantity: z.string().trim(), percentage: z.string().trim() }))
  .default([])

/**
 * Form-state row for a price rule. Carries `preference_schema` for the
 * editor alongside the payload fields the API consumes (`type`,
 * `preferences`, optional `id`). The rule's name and description are
 * resolved from `type` at render time, so no copy is stored here. Closely
 * mirrors `PromotionRuleFormDraft` so the editor patterns are 1:1.
 */
export interface PriceRuleFormDraft {
  /** Stable client-side id used as a React key while the row has no server id. */
  _localId: string
  /** Present once the row has been persisted. */
  id?: string
  /** Wire shorthand — `volume_rule`, `market_rule`, etc. */
  type: string
  preference_schema: PreferenceField[]
  preferences: Record<string, unknown>
  /**
   * Display-only embeds the per-rule editors set when the user picks
   * records via autocomplete. Used by `RuleSummary` so the row preview
   * reads "Customer groups: VIPs, Wholesale" instead of "cg_…". Never
   * sent to the API — `priceListValuesToParams` strips them.
   */
  customers?: RuleEmbedRecord[]
  customer_groups?: RuleEmbedRecord[]
  markets?: RuleEmbedRecord[]
  channels?: RuleEmbedRecord[]
}

/**
 * Display-only slice of an embed record — enough to render a label,
 * nothing more. Deliberately NOT the SDK types (`Customer`, `Channel`, …):
 * this interface is part of the form values, and react-hook-form's
 * `Path<T>` enumerates every nested key of the form type. The SDK types
 * embed the whole object graph (`Customer` → `orders[]` → `payments[]` →
 * `source` → …), which turns the path union into millions of keys and
 * overflows TypeScript's relation cache ("RangeError: Map maximum size
 * exceeded" on TS 6). Assigning a full SDK record INTO one of these
 * fields is fine — the editors do exactly that — but the form type must
 * stay shallow.
 */
export interface RuleEmbedRecord {
  id: string
  name?: string | null
  email?: string | null
  code?: string | null
}

const priceRuleDraftSchema: z.ZodType<PriceRuleFormDraft> = z.object({
  _localId: z.string(),
  id: z.string().optional(),
  type: z.string().min(1),
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
     * Quantity discounts derived from base prices: one direction for the
     * whole ladder, and the bands as magnitudes. A standalone list carries no
     * percentage of its own, only bands — a band applies from a quantity up,
     * so it cannot put the whole store on sale by accident
     * (docs/plans/6.0-volume-pricing.md).
     */
    adjustment_direction: z.enum(ADJUSTMENT_DIRECTIONS).default('decrease'),
    adjustment_tiers: adjustmentTierSchema,
    /**
     * Staged product membership, applied on Save through the nested products
     * endpoints. Opaque by design — it holds SDK `Product` records so a staged
     * addition can render before it exists server-side, and RHF's `Path<T>`
     * must not walk that object graph (same reason as `RuleEmbedRecord`).
     * Never sent to the API; `priceListValuesToParams` drops it.
     */
    staged_products: z.custom<ProductMembershipStagingValue>(() => true),
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
  .refine((v) => adjustmentTiersAreWellFormed(v.adjustment_tiers), {
    path: ['adjustment_tiers'],
    error: () => i18n.t('admin.products.price_lists.validation.tier_quantity_invalid'),
  })
  .refine(
    (v) => v.adjustment_tiers.every((tier) => tierPercentageIsUsable(tier, v.adjustment_direction)),
    {
      path: ['adjustment_tiers'],
      error: () => i18n.t('admin.products.price_lists.validation.tier_percentage_invalid'),
    },
  )

/**
 * A positive percentage, or null when absent or unparseable. The flat
 * percentage is valid only on a list a catalog owns, so the standalone editor
 * offers only its quantity bands.
 */
export function parsePercentage(value: string | undefined): number | null {
  if (!value?.trim()) return null
  const parsed = Number(value)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null
}

/**
 * A whole-number quantity threshold, or null when absent or unusable. One
 * parse for the validation, the write and the read, so the field cannot
 * accept a value it then silently discards.
 */
export function parseMinimumQuantity(value: string | number | undefined | null): number | null {
  const text = typeof value === 'string' ? value.trim() : value
  if (text === '' || text === null || text === undefined) return null

  const parsed = Number(text)
  return Number.isInteger(parsed) && parsed >= 1 ? parsed : null
}

export type PriceListFormValues = z.infer<typeof priceListFormSchema>

export const PRICE_LIST_DEFAULTS: PriceListFormValues = {
  name: '',
  description: '',
  starts_at: null,
  ends_at: null,
  match_policy: 'all',
  rules: [],
  adjustment_direction: 'decrease',
  adjustment_tiers: [],
  staged_products: { adds: [], removes: [] },
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
    // The payload is the whole ladder, so a band the merchant deleted is a
    // band absent from this array rather than one marked for removal.
    price_adjustment_tiers: adjustmentTiersPayload(v.adjustment_tiers, v.adjustment_direction),
  }
}

/**
 * Bands as the API takes them: signed percentages, matching the one
 * direction chosen for the list. A band a merchant enters as "20" under
 * "decrease" is -20 — one control for direction, so a ladder cannot
 * half-discount and half-mark-up.
 */
export function adjustmentTiersPayload(
  tiers: AdjustmentTierValue[],
  direction: AdjustmentDirection,
) {
  return tiers.flatMap((tier) => {
    const quantity = parseMinimumQuantity(tier.min_quantity)
    const magnitude = parsePercentage(tier.percentage)
    if (quantity === null || quantity < 2 || magnitude === null) return []

    return [
      {
        min_quantity: quantity,
        percentage: String(direction === 'decrease' ? -magnitude : magnitude),
      },
    ]
  })
}

/** Every band above one unit, and no quantity used twice. */
export function adjustmentTiersAreWellFormed(tiers: AdjustmentTierValue[]): boolean {
  const quantities = tiers.map((tier) => parseMinimumQuantity(tier.min_quantity))
  if (quantities.some((quantity) => quantity === null || quantity < 2)) return false

  return new Set(quantities).size === quantities.length
}

/**
 * A discount past 100% would price below zero; a markup has no ceiling short
 * of what the column holds. The same bound the list's own figure carries.
 */
export function tierPercentageIsUsable(
  tier: AdjustmentTierValue,
  direction: AdjustmentDirection,
): boolean {
  const magnitude = parsePercentage(tier.percentage)
  if (magnitude === null) return false

  return direction === 'increase' || magnitude < 100
}

/**
 * Splits stored signed bands back into the edited direction and magnitudes.
 * The shallowest band decides the ladder's direction: the form offers one
 * increase/decrease control, and the magnitudes are read through it.
 */
export function adjustmentTiersFormValues(bands: PriceList['price_adjustment_tiers']): {
  adjustment_direction: AdjustmentDirection
  adjustment_tiers: AdjustmentTierValue[]
} {
  const rows = bands ?? []
  return {
    adjustment_direction: Number(rows[0]?.percentage) > 0 ? 'increase' : 'decrease',
    adjustment_tiers: rows.map((tier) => ({
      min_quantity: String(tier.min_quantity),
      percentage: String(Math.abs(Number(tier.percentage))),
    })),
  }
}

/** Splits the stored signed percentage back into the edited pair. */
export function adjustmentFormValues(percentage: string | null | undefined): {
  pricing_mode: PricingMode
  adjustment_direction: AdjustmentDirection
  adjustment_magnitude: string
} {
  const parsed = percentage == null || percentage === '' ? null : Number(percentage)
  // Zero is no adjustment, and the form's own rules require a magnitude
  // above zero for automatic mode — loading it as automatic would leave the
  // page unsaveable until the user noticed the error.
  if (parsed === null || !Number.isFinite(parsed) || parsed === 0) {
    return { pricing_mode: 'fixed', adjustment_direction: 'decrease', adjustment_magnitude: '' }
  }

  return {
    pricing_mode: 'automatic',
    adjustment_direction: parsed < 0 ? 'decrease' : 'increase',
    adjustment_magnitude: String(Math.abs(parsed)),
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
  preference_schema: PreferenceField[]
}): PriceRuleFormDraft {
  return {
    _localId: newLocalId(),
    type: type.type,
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

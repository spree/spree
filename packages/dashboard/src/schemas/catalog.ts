import type { CatalogParams, PriceList } from '@spree/admin-sdk'
import { blankToNull, normalizeQuantityRule } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { z } from 'zod/v4'
import type { ProductMembershipStagingValue } from '../components/spree/product-membership-staging'
import {
  ADJUSTMENT_DIRECTIONS,
  adjustmentFormValues,
  PRICING_MODES,
  parseMinimumQuantity,
  parsePercentage,
} from './price-list'

/**
 * How a catalog prices. `base` is no list at all — the buyer pays the normal
 * price and the catalog only decides what they see. The other two stand up a
 * list the catalog owns: `automatic` derives from base prices by a
 * percentage, `fixed` holds the prices a merchant enters
 * (docs/plans/6.0-catalog-agreement-rework.md).
 */
export const CATALOG_PRICING_MODES = ['base', ...PRICING_MODES] as const
export type CatalogPricingMode = (typeof CATALOG_PRICING_MODES)[number]

/** Validation for the catalog create sheet and the agreement editor. */
export const catalogFormSchema = z
  .object({
    name: z.string().min(1, { error: requiredMessage('name') }),
    description: z.string().trim().optional(),
    /**
     * Staged product membership, applied on Save through the nested products
     * endpoints. Opaque by design — it holds SDK `Product` records so a staged
     * addition can render before it exists server-side, and RHF's `Path<T>`
     * must not walk that object graph. Never sent to the API;
     * `catalogValuesToParams` drops it.
     */
    staged_products: z.custom<ProductMembershipStagingValue>(() => true),
    /**
     * Split for editing, recombined into the inline `price_list` payload by
     * `catalogValuesToParams`.
     */
    pricing_mode: z.enum(CATALOG_PRICING_MODES).default('base'),
    adjustment_direction: z.enum(ADJUSTMENT_DIRECTIONS).default('decrease'),
    adjustment_magnitude: z.string().trim().optional(),
    adjust_compare_at: z.boolean().default(false),
    /**
     * The quantity an order line must reach before the adjustment applies,
     * carried as the owned list's volume rule. Blank means the agreement
     * prices every quantity — which is what most agreements do
     * (docs/plans/6.0-price-list-automatic-pricing.md).
     */
    minimum_quantity: z.string().trim().optional(),
    /**
     * The catalog-wide quantity terms — the middle of the three levels a
     * buyer's rules resolve through. Blank means this agreement is silent,
     * which passes the question down rather than answering it.
     *
     * Distinct from `minimum_quantity` above: that one decides when a
     * discount starts, these decide what a buyer may order at all.
     */
    minimum_order_quantity: z.string().trim().optional(),
    order_multiple: z.string().trim().optional(),
    /**
     * Per-product terms as edited on the assortment rows, keyed by product
     * id. Blank cells mean "uses the catalog default", so an entry whose
     * pair is empty is a deletion rather than an absence.
     *
     * Opaque to Zod for the same reason `staged_products` is: it is form
     * bookkeeping the submit handler consumes, never part of the parsed
     * payload.
     */
    staged_terms: z.custom<StagedProductTerms>(() => true),
    /**
     * The order minimums as edited, one row per currency. Staged like
     * everything else on the page: writing them on click inside a
     * dirty-tracked form meant Discard did not undo them.
     */
    order_minimums: z.custom<OrderMinimumEntry[]>(() => true),
    /**
     * Who this agreement is shown to, as edited. Staged like the rest of the
     * page so Save applies it and Discard rolls it back.
     */
    assignments: z.custom<AssignmentEntry[]>(() => true),
  })
  // Blank is a valid answer — it means the agreement states nothing — so the
  // shared normalizer's null stands for both "unset" and "unusable", and only
  // a non-blank field that normalizes away is an error.
  .refine(
    (v) =>
      !v.minimum_order_quantity?.trim() || normalizeQuantityRule(v.minimum_order_quantity) !== null,
    {
      path: ['minimum_order_quantity'],
      error: () => i18n.t('admin.catalogs.terms.validation.positive_integer'),
    },
  )
  .refine((v) => !v.order_multiple?.trim() || normalizeQuantityRule(v.order_multiple) !== null, {
    path: ['order_multiple'],
    error: () => i18n.t('admin.catalogs.terms.validation.positive_integer'),
  })
  // Only while the field is on screen. The value survives a switch away from
  // automatic pricing, and judging it then would block Save over a field the
  // merchant can no longer see or correct.
  .refine(
    (v) =>
      v.pricing_mode !== 'automatic' ||
      !v.minimum_quantity?.trim() ||
      parseMinimumQuantity(v.minimum_quantity) !== null,
    {
      path: ['minimum_quantity'],
      error: () => i18n.t('admin.products.price_lists.validation.minimum_quantity_invalid'),
    },
  )
  .refine(
    (v) => v.pricing_mode !== 'automatic' || parsePercentage(v.adjustment_magnitude) !== null,
    {
      path: ['adjustment_magnitude'],
      error: () => i18n.t('admin.products.price_lists.validation.adjustment_required'),
    },
  )
  .refine(
    (v) => {
      if (v.pricing_mode !== 'automatic' || v.adjustment_direction !== 'decrease') return true
      const magnitude = parsePercentage(v.adjustment_magnitude)
      return magnitude === null || magnitude < 100
    },
    {
      path: ['adjustment_magnitude'],
      error: () => i18n.t('admin.products.price_lists.validation.adjustment_too_deep'),
    },
  )

/**
 * A product's quantity terms as typed. Both fields are strings so an
 * unusable entry can be reported rather than silently coerced, and `mixed`
 * marks a product whose variants currently disagree — typing over it sets
 * them all.
 */
export interface ProductTermEntry {
  minimum_order_quantity: string
  order_multiple: string
  mixed?: boolean
}

/** Per-product terms staged on the assortment rows, keyed by product id. */
export type StagedProductTerms = Record<string, ProductTermEntry>

/**
 * One currency's order minimum as edited. `id` is present for a row that
 * exists server-side, absent for one the merchant just added — which is how
 * the save tells a create from an update.
 */
export interface OrderMinimumEntry {
  id?: string
  currency: string
  amount: string
}

/**
 * One audience this catalog is shown to. `id` is present for an assignment
 * that exists server-side and absent for one just added; the type and id of
 * the audience are what identify it, since a company and a customer group
 * can share an id.
 */
export interface AssignmentEntry {
  id?: string
  assignable_type: 'company' | 'customer_group'
  assignable_id: string
  assignable_name?: string | null
  /**
   * Staged for withdrawal. The row stays on screen struck through with an
   * undo, the way a product staged for removal does — Save is what actually
   * withdraws it, so it is dropped from the payload rather than the list.
   */
  removed?: boolean
}

/** Values the catalog form holds. */
export type CatalogFormValues = z.infer<typeof catalogFormSchema>

/**
 * A new catalog: named on create and priced by base prices. Whether it
 * applies is not a field here at all — going live is its own act, through
 * Catalogs::Activate (docs/plans/6.0-catalog-agreement-rework.md).
 */
export const CATALOG_DEFAULTS: CatalogFormValues = {
  name: '',
  description: '',
  pricing_mode: 'base',
  adjustment_direction: 'decrease',
  adjustment_magnitude: '',
  adjust_compare_at: false,
  minimum_quantity: '',
  minimum_order_quantity: '',
  order_multiple: '',
  staged_products: { adds: [], removes: [] },
  staged_terms: {},
  order_minimums: [],
  assignments: [],
}

/**
 * Maps form values to the Admin API payload. The catalog and the list it
 * prices through are written in one request, so `price_list` rides inline:
 * an object stands the list up or updates it, and an explicit null detaches
 * — which is a deliberate act, since a released list starts matching by its
 * own rules again.
 */
export function catalogValuesToParams(
  values: CatalogFormValues,
  /** The mode the catalog was saved in, so a switch can be told from a plain save. */
  previousMode?: CatalogPricingMode,
): CatalogParams {
  return {
    name: values.name,
    description: blankToNull(values.description),
    // `active` is deliberately absent: going live is its own act through the
    // activate endpoint, so a plain Save never changes whether an agreement
    // applies (docs/plans/6.0-catalog-agreement-rework.md).
    minimum_order_quantity: normalizeQuantityRule(values.minimum_order_quantity),
    order_multiple: normalizeQuantityRule(values.order_multiple),
    // Whole-set writes riding the catalog's own save, so the agreement lands
    // in one transaction rather than a sequence a failure can leave half
    // applied. Per-product terms stay their own request — an agreement may
    // name thousands of them.
    // Rows staged for withdrawal are simply absent: the endpoint replaces
    // the whole audience, so leaving one out is what removes it.
    assignments: values.assignments
      .filter((entry) => !entry.removed)
      .map((entry) => ({
        assignable_type: entry.assignable_type,
        assignable_id: entry.assignable_id,
      })),
    order_minimums: values.order_minimums.map((row) => ({
      currency: row.currency,
      amount: row.amount,
    })),
    price_list: priceListPayload(values, previousMode),
  }
}

function priceListPayload(values: CatalogFormValues, previousMode?: CatalogPricingMode) {
  if (values.pricing_mode === 'base') return null

  if (values.pricing_mode === 'fixed') {
    // A fixed list holds explicit rows; clearing any adjustment is what
    // makes it fixed. The quantity threshold goes with the percentage — left
    // behind it would gate the hand-entered prices, and the card stops
    // showing it, so nothing would explain the gap. `rules: []` clears only
    // the contextual ones; the server keeps the rest.
    return { price_adjustment_percentage: null, adjust_compare_at: false, rules: [] }
  }

  const magnitude = parsePercentage(values.adjustment_magnitude)
  const base =
    magnitude === null
      ? { adjust_compare_at: values.adjust_compare_at }
      : {
          price_adjustment_percentage: String(
            values.adjustment_direction === 'decrease' ? -magnitude : magnitude,
          ),
          adjust_compare_at: values.adjust_compare_at,
        }

  // A minimum quantity rides as the list's volume rule; dropping it from the
  // list of rules is what clears it, so removing the threshold is a real
  // edit rather than a silent no-op.
  const withRule = { ...base, rules: volumeRulePayload(values.minimum_quantity) }

  // Switching away from hand-entered prices clears them. An explicit amount
  // beats the adjustment by design, so leaving the old rows behind would
  // keep charging them while the card claims a percentage is in effect.
  return previousMode === 'fixed' ? { ...withRule, prices: [] } : withRule
}

function volumeRulePayload(minimumQuantity: string | undefined) {
  const quantity = parseMinimumQuantity(minimumQuantity)
  // A threshold of 1 gates nothing, which is exactly what blank means, so
  // both send no rule at all rather than one that always matches.
  if (quantity === null || quantity === 1) return []

  return [{ type: 'volume_rule', preferences: { min_quantity: quantity } }]
}

/**
 * Splits a catalog's owned list back into the edited fields. No list means
 * the catalog prices at base.
 */
export function catalogPricingValues(
  priceList:
    | Pick<PriceList, 'price_adjustment_percentage' | 'adjust_compare_at' | 'price_rules'>
    | null
    | undefined,
): {
  pricing_mode: CatalogPricingMode
  adjustment_direction: CatalogFormValues['adjustment_direction']
  adjustment_magnitude: string
  adjust_compare_at: boolean
  minimum_quantity: string
} {
  if (!priceList) {
    return {
      pricing_mode: 'base',
      adjustment_direction: 'decrease',
      adjustment_magnitude: '',
      adjust_compare_at: false,
      minimum_quantity: '',
    }
  }

  const { pricing_mode, adjustment_direction, adjustment_magnitude } = adjustmentFormValues(
    priceList.price_adjustment_percentage,
  )

  return {
    pricing_mode,
    adjustment_direction,
    adjustment_magnitude,
    adjust_compare_at: priceList.adjust_compare_at ?? false,
    minimum_quantity: minimumQuantityOf(priceList.price_rules),
  }
}

/**
 * The volume rule's threshold, as the string the input edits. Shows whatever
 * the rule holds — including a 1 set through the API or the standalone rules
 * editor — because a value the field hides is a value the next Save destroys
 * without the merchant ever seeing it.
 */
function minimumQuantityOf(rules: PriceList['price_rules']): string {
  const rule = rules?.find((entry) => entry.type === 'volume_rule')
  const quantity = parseMinimumQuantity(
    rule?.preferences?.min_quantity as string | number | undefined,
  )

  return quantity === null ? '' : String(quantity)
}

import type { CatalogParams, PriceList } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
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
    active: z.boolean(),
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
  })
  .refine((v) => isBlankOrPositiveInteger(v.minimum_order_quantity), {
    path: ['minimum_order_quantity'],
    error: () => i18n.t('admin.catalogs.terms.validation.positive_integer'),
  })
  .refine((v) => isBlankOrPositiveInteger(v.order_multiple), {
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

/** Values the catalog form holds. */
export type CatalogFormValues = z.infer<typeof catalogFormSchema>

/** A new catalog: named on create, active, priced by base prices. */
export const CATALOG_DEFAULTS: CatalogFormValues = {
  name: '',
  description: '',
  active: true,
  pricing_mode: 'base',
  adjustment_direction: 'decrease',
  adjustment_magnitude: '',
  adjust_compare_at: false,
  minimum_quantity: '',
  minimum_order_quantity: '',
  order_multiple: '',
  staged_products: { adds: [], removes: [] },
}

/** Blank is a valid answer — it means the agreement states nothing. */
function isBlankOrPositiveInteger(value: string | undefined): boolean {
  if (!value?.trim()) return true
  return /^\d+$/.test(value.trim()) && Number(value) > 0
}

/** Parses a terms field, where blank means "say nothing" rather than zero. */
export function parseTermQuantity(value: string | undefined): number | null {
  const trimmed = value?.trim()
  return trimmed ? Number(trimmed) : null
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
    active: values.active,
    minimum_order_quantity: parseTermQuantity(values.minimum_order_quantity),
    order_multiple: parseTermQuantity(values.order_multiple),
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

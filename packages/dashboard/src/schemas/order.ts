import type { LineItem, OrderUpdateParams } from '@spree/admin-sdk'
import { i18n } from '@spree/dashboard-core'
import { z } from 'zod/v4'
import { fulfilledQuantities, type GroupableFulfillment } from '../lib/fulfillment-items'

/**
 * New-order form schema. The "customer OR email" rule is enforced at the
 * page level rather than in this schema because `customer` lives outside
 * the RHF state (it's a domain object held in `useState` for the resource
 * combobox). See `routes/_authenticated/$storeId/orders/new.tsx` for the
 * combined `canSubmit` check.
 *
 * Per-attribute server validation (line items, customer reachability, etc.)
 * comes back as a 422 and gets routed through `mapSpreeErrorsToForm`.
 */
export const newOrderFormSchema = z.object({
  email: z
    .string()
    .email({ error: () => i18n.t('admin.validation.invalid_email') })
    .or(z.literal('')),
  customer_note: z.string(),
  internal_note: z.string(),
  coupon_code: z.string(),
  // Empty string = "use store default" (resolved server-side via
  // Order#ensure_channel_presence).
  channel_id: z.string(),
})

export type NewOrderFormValues = z.infer<typeof newOrderFormSchema>

export const NEW_ORDER_DEFAULTS: NewOrderFormValues = {
  email: '',
  customer_note: '',
  internal_note: '',
  coupon_code: '',
  channel_id: '',
}

/**
 * Fee kinds offered when adding a manual fee to an order. The backend accepts
 * any string, so this is the curated admin-facing set, not a DB constraint.
 */
export const FEE_KINDS = ['surcharge', 'handling', 'gift_wrap', 'cod', 'payment', 'duty'] as const

export type FeeKind = (typeof FEE_KINDS)[number]

/**
 * One row of the order edit table. Everything here is a primitive on purpose:
 * embedding an SDK entity would make react-hook-form's `Path<T>` walk the whole
 * order graph (see CLAUDE.md), so the display columns are copied in flat.
 *
 * `removed` and `added` are staging flags — they say what the merchant has
 * asked for, not what the server holds. Nothing leaves the browser until Save.
 */
export const orderEditItemSchema = z
  .object({
    variant_id: z.string(),
    quantity: z
      .number()
      .int()
      .min(1, {
        error: () =>
          i18n.t('admin.validation.positive_number', {
            field: i18n.t('admin.fields.quantity.label'),
          }),
      }),
    removed: z.boolean(),
    /** True for rows the picker staged that the order does not have yet. */
    added: z.boolean(),
    /** Quantity the server currently holds; 0 for staged additions. */
    saved_quantity: z.number().int(),
    /** Units already shipped in fulfilled fulfillments; 0 for staged additions. */
    fulfilled_quantity: z.number().int(),
    /**
     * Editable unit price (decimal string) — only rendered as an input on
     * draft orders. A change stamps the line `price_source: 'manual'` on save.
     * Its format is checked in the refinement below rather than here, so a
     * row being removed is not held up by a price that will never be sent.
     */
    price: z.string(),
    /** Price the server currently holds; the initial catalog price for staged additions. */
    saved_price: z.string(),
    /** Provenance from the server; 'manual' marks a negotiated line. */
    price_source: z.string().nullable(),
    /**
     * The variant's base catalog price, for previewing what a revert restores.
     * Indicative only — the revert re-prices through the resolver, which may
     * land on a price-list or contract amount instead.
     */
    catalog_price: z.string().nullable(),
    /** Staged "reset to catalog price" — sends `price: null` on save. */
    revert_price: z.boolean(),
    name: z.string(),
    options_text: z.string(),
    thumbnail_url: z.string().nullable(),
    display_price: z.string(),
    display_total: z.string(),
  })
  .superRefine((item, ctx) => {
    // A removed row's price is never sent (the payload carries quantity 0),
    // so refusing the form over it would block a legitimate removal — the
    // obvious way out of having typed a bad price in the first place.
    // A staged revert is exempt too: it sends `price: null`.
    if (!item.removed && !item.revert_price && !/^\d+(\.\d+)?$/.test(item.price)) {
      ctx.addIssue({
        code: 'custom',
        path: ['price'],
        message: i18n.t('admin.orders.edit.validation.invalid_price'),
      })
    }

    // Shipped units are physical fact: a row can neither be struck out nor
    // set below what already left the warehouse. Removal counts as zero, so
    // one rule covers both edits.
    const effectiveQuantity = item.removed ? 0 : item.quantity

    if (effectiveQuantity < item.fulfilled_quantity) {
      ctx.addIssue({
        code: 'custom',
        path: ['quantity'],
        message: i18n.t('admin.orders.edit.validation.below_fulfilled', {
          count: item.fulfilled_quantity,
        }),
      })
    }
  })

export type OrderEditItemValues = z.infer<typeof orderEditItemSchema>

export const orderEditFormSchema = z.object({
  items: z.array(orderEditItemSchema),
})

export type OrderEditFormValues = z.infer<typeof orderEditFormSchema>

/** Builds the staged row for a line item the order already carries. */
export function lineItemToEditRow(item: LineItem, fulfilledQuantity = 0): OrderEditItemValues {
  return {
    variant_id: item.variant_id,
    quantity: item.quantity,
    removed: false,
    added: false,
    saved_quantity: item.quantity,
    fulfilled_quantity: fulfilledQuantity,
    price: item.price,
    saved_price: item.price,
    price_source: item.price_source ?? null,
    catalog_price: item.catalog_price ?? null,
    revert_price: false,
    name: item.name,
    options_text: item.options_text ?? '',
    thumbnail_url: item.thumbnail_url,
    display_price: item.display_price,
    display_total: item.display_total,
  }
}

export function orderToEditForm(
  items: LineItem[],
  fulfillments: GroupableFulfillment[] = [],
): OrderEditFormValues {
  const fulfilled = fulfilledQuantities(fulfillments)

  return { items: items.map((item) => lineItemToEditRow(item, fulfilled.get(item.id) ?? 0)) }
}

/**
 * Reduces staged rows to the `items` upsert the Admin API expects. The endpoint
 * is keyed by variant and touches only what it is sent, so untouched rows are
 * omitted, staged removals become `quantity: 0`, and additions carry their
 * quantity like any other change.
 *
 * A row that was staged and then unstaged in the same session contributes
 * nothing, which is why an addition whose `removed` flag is set drops out
 * entirely rather than sending a pointless `0`.
 */
/**
 * Formats a projected amount in the order's currency. Only for previews the
 * client computes — server-sent money always arrives pre-formatted as
 * `display_*`, and rendering that through here would risk disagreeing with it.
 */
export function formatAmount(amount: number, currency: string): string {
  return new Intl.NumberFormat(i18n.language, { style: 'currency', currency }).format(amount)
}

/**
 * The unit price a row will end up at once saved, or null when it cannot be
 * known client-side — a staged revert on a line whose catalog price the server
 * did not send. Callers render the saved price unchanged in that case rather
 * than inventing a number.
 */
export function projectedPrice(item: OrderEditItemValues): number | null {
  const source = item.revert_price ? item.catalog_price : item.price
  if (source == null || source === '') return null

  const parsed = Number(source)
  return Number.isFinite(parsed) ? parsed : null
}

/**
 * What the line will cost after saving. Removed rows contribute nothing.
 * Null propagates from {@link projectedPrice} so an unknowable line leaves the
 * whole projection unknowable rather than silently under-counting the order.
 */
export function projectedLineTotal(item: OrderEditItemValues): number | null {
  if (item.removed) return 0

  const price = projectedPrice(item)
  return price === null ? null : price * item.quantity
}

/**
 * The order's projected item subtotal. Null when any row's price cannot be
 * projected — a partial sum shown as a total would be a wrong number stated
 * confidently, which is worse than showing the server's last known figure.
 */
export function projectedSubtotal(items: OrderEditItemValues[]): number | null {
  let sum = 0
  for (const item of items) {
    const total = projectedLineTotal(item)
    if (total === null) return null
    sum += total
  }
  return sum
}

export type OrderItemsPayload = NonNullable<OrderUpdateParams['items']>

export function buildOrderItemsPayload(items: OrderEditItemValues[]): OrderItemsPayload {
  const payload: OrderItemsPayload = []

  for (const item of items) {
    if (item.removed) {
      if (!item.added) payload.push({ variant_id: item.variant_id, quantity: 0 })
      continue
    }

    // A staged revert sends the explicit `price: null` gesture; an edited
    // price rides along stamped manual. An untouched price is omitted so the
    // server never mistakes "unchanged" for "negotiated at this amount".
    const priceChange = item.revert_price
      ? { price: null }
      : item.price !== item.saved_price
        ? { price: item.price }
        : undefined

    if (item.added || item.quantity !== item.saved_quantity || priceChange) {
      payload.push({ variant_id: item.variant_id, quantity: item.quantity, ...priceChange })
    }
  }

  return payload
}

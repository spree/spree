import type { LineItem, OrderUpdateParams } from '@spree/admin-sdk'
import { fulfilledQuantities, type GroupableFulfillment, i18n } from '@spree/dashboard-core'
import { z } from 'zod/v4'

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
  // The buyer's own purchase-order reference — a PO arriving by email and
  // keyed in is this form plus this field.
  po_number: z.string(),
  coupon_code: z.string(),
  // Empty string = "use store default" (resolved server-side via
  // Order#ensure_channel_presence).
  channel_id: z.string(),
})

export type NewOrderFormValues = z.infer<typeof newOrderFormSchema>

/**
 * Cancelling an order. The reason is an id from the store's own cancellation
 * vocabulary, and an empty string means the merchant gave none.
 */
export const NEW_ORDER_DEFAULTS: NewOrderFormValues = {
  email: '',
  customer_note: '',
  internal_note: '',
  po_number: '',
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
    /** Editable on drafts; a change stamps `price_source: 'manual'`. Format
     * checked in the refinement below, so a removed row is not held up. */
    price: z.string(),
    /** Price the server currently holds; the initial catalog price for staged additions. */
    saved_price: z.string(),
    /** Provenance from the server; 'manual' marks a negotiated line. */
    price_source: z.string().nullable(),
    /** Base catalog price, for previewing a revert. Indicative: the revert
     * re-prices through the resolver. */
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
    // Neither case sends a price, so refusing the form over one would block a
    // legitimate removal.
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

/** Formats a client-computed preview amount; server money arrives as `display_*`. */
export function formatAmount(amount: number, currency: string): string {
  return new Intl.NumberFormat(i18n.language, { style: 'currency', currency }).format(amount)
}

/** The price a row lands on once saved, or null when it cannot be known. */
export function projectedPrice(item: OrderEditItemValues): number | null {
  const source = item.revert_price ? item.catalog_price : item.price
  if (source == null || source === '') return null

  const parsed = Number(source)
  return Number.isFinite(parsed) ? parsed : null
}

/** What the line costs after saving; null propagates so a total is never partial. */
export function projectedLineTotal(item: OrderEditItemValues): number | null {
  if (item.removed) return 0

  const price = projectedPrice(item)
  return price === null ? null : price * item.quantity
}

/** Projected item subtotal; null if any row is unprojectable. */
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

/**
 * Reduces staged rows to the `items` upsert the Admin API expects: untouched
 * rows are omitted, removals become `quantity: 0`, and a row staged then
 * unstaged contributes nothing.
 */
export function buildOrderItemsPayload(items: OrderEditItemValues[]): OrderItemsPayload {
  const payload: OrderItemsPayload = []

  for (const item of items) {
    if (item.removed) {
      if (!item.added) payload.push({ variant_id: item.variant_id, quantity: 0 })
      continue
    }

    // An untouched price is omitted so the server does not read "unchanged"
    // as "negotiated at this amount".
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

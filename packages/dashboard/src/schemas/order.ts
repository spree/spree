import type { LineItem, OrderUpdateParams } from '@spree/admin-sdk'
import { i18n } from '@spree/dashboard-core'
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
export const FEE_KINDS = ['surcharge', 'handling', 'gift_wrap', 'cod', 'payment'] as const

export type FeeKind = (typeof FEE_KINDS)[number]

/**
 * One row of the order edit table. Everything here is a primitive on purpose:
 * embedding an SDK entity would make react-hook-form's `Path<T>` walk the whole
 * order graph (see CLAUDE.md), so the display columns are copied in flat.
 *
 * `removed` and `added` are staging flags — they say what the merchant has
 * asked for, not what the server holds. Nothing leaves the browser until Save.
 */
export const orderEditItemSchema = z.object({
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
  name: z.string(),
  options_text: z.string(),
  thumbnail_url: z.string().nullable(),
  display_price: z.string(),
  display_total: z.string(),
})

export type OrderEditItemValues = z.infer<typeof orderEditItemSchema>

export const orderEditFormSchema = z.object({
  items: z.array(orderEditItemSchema),
})

export type OrderEditFormValues = z.infer<typeof orderEditFormSchema>

/** Builds the staged row for a line item the order already carries. */
export function lineItemToEditRow(item: LineItem): OrderEditItemValues {
  return {
    variant_id: item.variant_id,
    quantity: item.quantity,
    removed: false,
    added: false,
    saved_quantity: item.quantity,
    name: item.name,
    options_text: item.options_text ?? '',
    thumbnail_url: item.thumbnail_url,
    display_price: item.display_price,
    display_total: item.display_total,
  }
}

export function orderToEditForm(items: LineItem[]): OrderEditFormValues {
  return { items: items.map(lineItemToEditRow) }
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
export type OrderItemsPayload = NonNullable<OrderUpdateParams['items']>

export function buildOrderItemsPayload(items: OrderEditItemValues[]): OrderItemsPayload {
  const payload: OrderItemsPayload = []

  for (const item of items) {
    if (item.removed) {
      if (!item.added) payload.push({ variant_id: item.variant_id, quantity: 0 })
      continue
    }

    if (item.added || item.quantity !== item.saved_quantity) {
      payload.push({ variant_id: item.variant_id, quantity: item.quantity })
    }
  }

  return payload
}

/**
 * Which line items sit in which fulfillment, and which units nobody has
 * claimed yet. The order payload describes the two halves separately —
 * `order.items` is the full basket, each fulfillment carries its own
 * `fulfillment_items` — so the card has to join them back together to say
 * what is being shipped where.
 */

/** The line-item fields the grouping reads. */
export interface GroupableLineItem {
  id: string
  name: string
  options_text?: string | null
  quantity: number
  thumbnail_url?: string | null
  display_price?: string | null
  display_total?: string | null
}

/** The fulfillment-item fields the grouping reads. */
export interface GroupableFulfillmentItem {
  line_item_id?: string | null
  variant_id?: string | null
  name?: string | null
  options_text?: string | null
  quantity: number
}

/** The fulfillment fields the grouping reads. */
export interface GroupableFulfillment {
  status: string
  fulfillment_items?: GroupableFulfillmentItem[] | null
}

/**
 * One row in a fulfillment's (or the unfulfilled group's) item list: the
 * line item it descends from, plus how many of its units this group holds.
 */
export interface FulfillmentItemRow {
  /** Stable within one group — a line item appears at most once per group. */
  key: string
  lineItem: GroupableLineItem | null
  /** Falls back to the fulfillment item's own copy when the line item is gone. */
  name: string
  optionsText: string | null
  thumbnailUrl: string | null
  displayPrice: string | null
  quantity: number
}

/**
 * Statuses whose units `Spree::Fulfillments::Create` will still move into a
 * new fulfillment. Anything shipped or canceled is settled and its units are
 * no longer fulfillable — mirrors `fulfillable_units` in
 * `spree/core/app/workflows/spree/fulfillments/create.rb`.
 */
const MOVABLE_STATUSES = ['pending', 'ready', 'ready_for_pickup']

/**
 * Sums, per line item, how many units every fulfillment claims. Fulfillment
 * items that reference no line item are skipped — there is nothing to join
 * them to, and counting them would understate the remainder.
 */
function claimedQuantities(fulfillments: GroupableFulfillment[]): Map<string, number> {
  const claimed = new Map<string, number>()

  for (const fulfillment of fulfillments) {
    for (const item of fulfillment.fulfillment_items ?? []) {
      if (!item.line_item_id) continue
      claimed.set(item.line_item_id, (claimed.get(item.line_item_id) ?? 0) + item.quantity)
    }
  }

  return claimed
}

/** Builds a row, preferring the line item's own copy over the fulfillment item's. */
function buildRow(
  key: string,
  lineItem: GroupableLineItem | undefined,
  fallback: Pick<GroupableFulfillmentItem, 'name' | 'options_text'> | null,
  quantity: number,
): FulfillmentItemRow {
  return {
    key,
    lineItem: lineItem ?? null,
    name: lineItem?.name ?? fallback?.name ?? '',
    optionsText: lineItem?.options_text ?? fallback?.options_text ?? null,
    thumbnailUrl: lineItem?.thumbnail_url ?? null,
    displayPrice: lineItem?.display_price ?? null,
    quantity,
  }
}

/**
 * The items one fulfillment holds, joined to their line items for the image
 * and the price the fulfillment item does not carry. Several fulfillment
 * items can descend from the same line item (units split by on-hand versus
 * backordered status), so they are merged into a single row.
 */
export function fulfillmentItemRows(
  fulfillment: GroupableFulfillment,
  lineItems: GroupableLineItem[],
): FulfillmentItemRow[] {
  const byId = new Map(lineItems.map((lineItem) => [lineItem.id, lineItem]))
  const rows = new Map<string, FulfillmentItemRow>()

  for (const item of fulfillment.fulfillment_items ?? []) {
    // A fulfillment item with no line item still ships; key it by variant so
    // it renders rather than vanishing.
    const key = item.line_item_id ?? item.variant_id
    if (!key) continue

    const existing = rows.get(key)
    if (existing) {
      existing.quantity += item.quantity
      continue
    }

    rows.set(
      key,
      buildRow(
        key,
        item.line_item_id ? byId.get(item.line_item_id) : undefined,
        item,
        item.quantity,
      ),
    )
  }

  return [...rows.values()]
}

/**
 * Line-item units no fulfillment has claimed: the ordered quantity minus what
 * every fulfillment holds. Only positive remainders are returned, so an order
 * whose fulfillments account for everything yields an empty list.
 */
export function unfulfilledItemRows(
  lineItems: GroupableLineItem[],
  fulfillments: GroupableFulfillment[],
): FulfillmentItemRow[] {
  const claimed = claimedQuantities(fulfillments)

  return lineItems.flatMap((lineItem) => {
    const remainder = lineItem.quantity - (claimed.get(lineItem.id) ?? 0)
    if (remainder <= 0) return []

    return [buildRow(lineItem.id, lineItem, null, remainder)]
  })
}

/**
 * Whether removing this row would delete only the units it displays. Removal
 * acts on the whole line item, so a row showing part of one — the rest sitting
 * in another group — would take those other units with it. Offering removal
 * only on whole line items keeps the action honest about its blast radius.
 */
export function isRemovableRow(row: FulfillmentItemRow): boolean {
  return !!row.lineItem && row.quantity === row.lineItem.quantity
}

/**
 * Whether anything is left to put into a new fulfillment: either units nobody
 * has claimed, or units sitting in a fulfillment that has not shipped yet and
 * can therefore still be moved. Without this the create workflow would happily
 * build an empty fulfillment on a fully shipped order.
 */
export function hasFulfillableUnits(
  lineItems: GroupableLineItem[],
  fulfillments: GroupableFulfillment[],
): boolean {
  const movable = fulfillments.some(
    (fulfillment) =>
      MOVABLE_STATUSES.includes(fulfillment.status) &&
      (fulfillment.fulfillment_items ?? []).some((item) => item.quantity > 0),
  )

  return movable || unfulfilledItemRows(lineItems, fulfillments).length > 0
}

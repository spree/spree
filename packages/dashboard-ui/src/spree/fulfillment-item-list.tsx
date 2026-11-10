import type { ReactElement, ReactNode } from 'react'
import { Item, ItemActions } from '../ui/item'
import { CornerDownRightIcon } from './icons'
import { ProductIdentity } from './product-identity'

/** What an exchanged unit was swapped for. */
export type FulfillmentItemReplacement = {
  name: string
  optionsText?: string | null
  thumbnailUrl?: string | null
  productId?: string | null
  displayPrice?: string | null
  /** Read out before the replacement, since the arrow says it only by sight. */
  label?: string
}

/**
 * One row of a fulfillment's item list, already joined to its line item by
 * the caller. The image and the price are optional: a surface that does not
 * expose them renders the name and the count alone.
 *
 * `priceSource` is a node because saying where a price came from means
 * linking to it, and routing belongs to the app.
 */
export type FulfillmentItemRowData = {
  key: string
  name: string
  optionsText?: string | null
  thumbnailUrl?: string | null
  displayPrice?: string | null
  priceSource?: ReactNode
  /** Beside the name, for state the row's own surface tracks (a return's receipt). */
  badges?: ReactNode
  productId?: string | null
  /** An exchange's new item, shown under the one going back. */
  replacement?: FulfillmentItemReplacement
  quantity: number
}

/** Builds the link a product opens; routing belongs to the app. */
export type ProductLinkRender = (productId: string) => ReactElement

/**
 * What a fulfillment holds: what it looks like, what it costs and how many
 * units travel together.
 *
 * Read-only — changing what an order contains after placement belongs to the
 * order edit screen, not here. Shared by the operator's order page and the
 * seller's so a parcel's contents read the same on both, and by the return,
 * exchange and claim cards so a unit looks the same wherever it goes.
 */
function ItemRow({
  row,
  productLink,
}: {
  row: FulfillmentItemRowData
  productLink?: ProductLinkRender
}) {
  const linkFor = (productId?: string | null) =>
    productId && productLink ? productLink(productId) : undefined
  const replacement = row.replacement

  return (
    <div className="py-3">
      <Item className="flex-nowrap gap-3 rounded-none border-0 p-0">
        <ProductIdentity
          name={row.name}
          subtitle={row.optionsText}
          thumbnailUrl={row.thumbnailUrl}
          badges={row.badges}
          render={linkFor(row.productId)}
          className="flex-1"
        />

        <ItemActions className="min-w-0 shrink flex-col items-end gap-0 text-right text-muted-foreground text-base">
          {row.displayPrice ? (
            <span className="whitespace-nowrap">
              {row.displayPrice} × {row.quantity}
            </span>
          ) : (
            <span className="whitespace-nowrap">× {row.quantity}</span>
          )}
          {row.priceSource && <div className="max-w-full truncate text-xs">{row.priceSource}</div>}
        </ItemActions>
      </Item>

      {replacement && (
        <Item className="mt-4 flex-nowrap gap-3 rounded-none border-0 p-0 pl-3">
          <CornerDownRightIcon aria-hidden className="size-4 shrink-0 text-muted-foreground" />
          {replacement.label && <span className="sr-only">{replacement.label}</span>}
          <ProductIdentity
            name={replacement.name}
            subtitle={replacement.optionsText}
            thumbnailUrl={replacement.thumbnailUrl}
            render={linkFor(replacement.productId)}
            className="flex-1"
          />
          {replacement.displayPrice && (
            <ItemActions className="whitespace-nowrap text-muted-foreground text-base">
              {replacement.displayPrice} × {row.quantity}
            </ItemActions>
          )}
        </Item>
      )}
    </div>
  )
}

export function FulfillmentItemList({
  rows,
  productLink,
}: {
  rows: FulfillmentItemRowData[]
  /** Makes each product a link to its page. */
  productLink?: ProductLinkRender
}) {
  if (rows.length === 0) return null

  return (
    // Inset by margin so the rules between rows stop short of the card's edges.
    <div className="mx-4 divide-y">
      {rows.map((row) => (
        <ItemRow key={row.key} row={row} productLink={productLink} />
      ))}
    </div>
  )
}

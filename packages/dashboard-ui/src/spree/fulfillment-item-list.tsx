import type { ReactNode } from 'react'
import { Item, ItemActions, ItemContent, ItemDescription, ItemTitle } from '../ui/item'
import { Thumbnail } from '../ui/thumbnail'
import { PackageIcon } from './icons'

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
  quantity: number
}

/**
 * What a fulfillment holds: what it looks like, what it costs and how many
 * units travel together.
 *
 * Read-only — changing what an order contains after placement belongs to the
 * order edit screen, not here. Shared by the operator's order page and the
 * seller's so a parcel's contents read the same on both.
 */
function ItemRow({ row }: { row: FulfillmentItemRowData }) {
  return (
    <Item className="flex-nowrap gap-3 rounded-none border-0 p-3">
      <Thumbnail src={row.thumbnailUrl} fallback={<PackageIcon />} />

      <ItemContent className="min-w-0 gap-0">
        <ItemTitle className="block truncate">{row.name}</ItemTitle>
        {row.optionsText && (
          <ItemDescription className="line-clamp-1 text-xs">{row.optionsText}</ItemDescription>
        )}
      </ItemContent>

      <ItemActions className="min-w-0 shrink flex-col items-end gap-0 text-right text-muted-foreground text-sm">
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
  )
}

export function FulfillmentItemList({ rows }: { rows: FulfillmentItemRowData[] }) {
  if (rows.length === 0) return null

  return (
    <div className="divide-y">
      {rows.map((row) => (
        <ItemRow key={row.key} row={row} />
      ))}
    </div>
  )
}

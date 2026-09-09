import { Thumbnail } from '../ui/thumbnail'
import { PackageIcon } from './icons'

/**
 * One row of a fulfillment's item list, already joined to its line item by
 * the caller. The image and the price are optional: a surface that does not
 * expose them renders the name and the count alone.
 */
export type FulfillmentItemRowData = {
  key: string
  name: string
  optionsText?: string | null
  thumbnailUrl?: string | null
  displayPrice?: string | null
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
    <div className="flex items-center gap-3 p-3">
      <Thumbnail src={row.thumbnailUrl} fallback={<PackageIcon />} />

      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{row.name}</div>
        {row.optionsText && (
          <div className="truncate text-xs text-muted-foreground">{row.optionsText}</div>
        )}
      </div>

      <div className="shrink-0 whitespace-nowrap text-right text-muted-foreground text-sm">
        {row.displayPrice ? (
          <span>
            {row.displayPrice} × {row.quantity}
          </span>
        ) : (
          <span>× {row.quantity}</span>
        )}
      </div>
    </div>
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

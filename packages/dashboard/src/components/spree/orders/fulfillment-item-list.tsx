import { Thumbnail } from '@spree/dashboard-ui'
import { PackageIcon } from 'lucide-react'
import type { FulfillmentItemRow } from '../../../lib/fulfillment-items'

/**
 * One item inside a fulfillment group: what it looks like, what it costs and
 * how many units this group holds. Read-only — changing what an order contains
 * after placement belongs to the order edit screen, not here.
 */
function ItemRow({ row }: { row: FulfillmentItemRow }) {
  return (
    <div className="flex items-center gap-3 p-3">
      <Thumbnail src={row.thumbnailUrl} fallback={<PackageIcon />} />

      <div className="min-w-0 flex-1">
        <div className="truncate text-sm font-medium">{row.name}</div>
        {row.optionsText && (
          <div className="truncate text-xs text-muted-foreground">{row.optionsText}</div>
        )}
      </div>

      <div className="shrink-0 text-right text-sm whitespace-nowrap text-muted-foreground">
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

/** The item list rendered inside a fulfillment group. */
export function FulfillmentItemList({ rows }: { rows: FulfillmentItemRow[] }) {
  if (rows.length === 0) return null

  return (
    <div className="divide-y">
      {rows.map((row) => (
        <ItemRow key={row.key} row={row} />
      ))}
    </div>
  )
}

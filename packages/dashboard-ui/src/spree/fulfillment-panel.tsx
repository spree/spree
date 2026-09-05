import type { ReactNode } from 'react'
import { StatusBadge } from '../ui/badge'
import { Card, CardAction, CardHeader, CardTitle } from '../ui/card'
import { MapPinIcon } from './icons'

/**
 * The nested card one parcel occupies on an order page: what state it is in,
 * where it ships from, and its own menu.
 *
 * Shared by the operator's order page and the seller's, so a parcel reads the
 * same on both sides of a marketplace. Headless — the status label and every
 * action come from the caller.
 */
export function FulfillmentPanel({
  status,
  statusLabel,
  location,
  meta,
  actions,
  children,
}: {
  status: string
  /** Omit to let the badge humanize the status itself. */
  statusLabel?: string
  /** Where it ships from. Absent until a fulfillment exists. */
  location?: string | null
  /** Trailing header detail, e.g. when it shipped. */
  meta?: ReactNode
  /** The panel's own menu. Absent when there is nothing to act on. */
  actions?: ReactNode
  children: ReactNode
}) {
  return (
    <Card variant="nested">
      <CardHeader>
        <CardTitle className="min-w-0 font-normal text-sm">
          <StatusBadge status={status} label={statusLabel} />
          {location && (
            <div className="flex min-w-0 items-center gap-1.5 text-muted-foreground text-xs">
              <MapPinIcon className="size-3 shrink-0" />
              {/* The card clips its overflow, so a long warehouse name has to
                  truncate here or it is simply cut off. */}
              <span className="truncate">{location}</span>
            </div>
          )}
          {meta}
        </CardTitle>
        {actions && <CardAction>{actions}</CardAction>}
      </CardHeader>
      {children}
    </Card>
  )
}

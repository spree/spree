import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

interface ResourceNameCellProps {
  /** Resource identifier, mirrored into the bridge data attribute. */
  id: string
  /** Data attribute the `useRowClickBridge` listener targets (e.g. `data-payment-method-id`). */
  dataAttr: `data-${string}`
  /** Primary text — the resource's display name. */
  name: ReactNode
  /** Optional secondary line. Falsy values render nothing. */
  secondary?: ReactNode
  /** Extra classes for the primary `<span>` — useful for `tabular-nums` on ID/number columns. */
  nameClassName?: string
}

/**
 * Standard "name + secondary" cell used as the primary clickable target in
 * resource index tables. The wrapping `<button>` carries the bridge data
 * attribute so `useRowClickBridge` resolves the row → detail navigation.
 *
 * Stays purely presentational — routing is the parent table's job via the
 * bridge hook, not this component's. If you need a custom layout (icon
 * thumbnail, status pill inline with name, etc.), compose it inline rather
 * than overloading this cell with props.
 */
export function ResourceNameCell({
  id,
  dataAttr,
  name,
  secondary,
  nameClassName,
}: ResourceNameCellProps) {
  return (
    <button
      type="button"
      {...{ [dataAttr]: id }}
      className="flex h-full w-full cursor-pointer flex-col items-start rounded text-left focus-visible:outline-none"
    >
      <span className={cn('font-medium', nameClassName)}>{name}</span>
      {secondary && <span className="text-xs text-muted-foreground">{secondary}</span>}
    </button>
  )
}

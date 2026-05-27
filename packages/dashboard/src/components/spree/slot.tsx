import { Fragment } from 'react'
import { type SlotAmbientContext, useSlotEntries } from '@/lib/slot-registry'

interface SlotProps<TContext> {
  /** Slot name, e.g. "product.form_sidebar" or "order.dropdown". */
  name: string
  /** Slot-specific context passed to every registered component. */
  context?: TContext
  /**
   * Rendered when no entries are registered or all are gated out by `if`.
   * Useful when a slot is the only thing in a section (avoid empty headings).
   */
  fallback?: React.ReactNode
}

/**
 * Renders all components registered to a slot, sorted by `position`,
 * filtered by each entry's `if` predicate. Each component receives `context`
 * as props plus ambient `{ permissions, store, user }` (populated as the
 * providers come online).
 */
export function Slot<TContext extends object = object>({
  name,
  context,
  fallback,
}: SlotProps<TContext>) {
  const entries = useSlotEntries(name)

  // Ambient context — wired up properly once SlotProvider lands. For now
  // an empty object so plugin `if` predicates can destructure safely.
  const ambient: SlotAmbientContext = {}
  const merged = { ...ambient, ...(context ?? {}) } as TContext & SlotAmbientContext

  const visible = entries.filter((entry) => (entry.if ? entry.if(merged) : true))

  if (visible.length === 0) return fallback ?? null

  return (
    <>
      {visible.map((entry) => {
        const Component = entry.component
        return (
          <Fragment key={entry.id}>
            <Component {...merged} />
          </Fragment>
        )
      })}
    </>
  )
}

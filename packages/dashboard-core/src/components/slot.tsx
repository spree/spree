import { Fragment } from 'react'
import { FormProvider, type UseFormReturn } from 'react-hook-form'
import { type SlotAmbientContext, useSlotEntries } from '../lib/slot-registry'

export interface SlotProps<TContext> {
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

/**
 * A slot inside a form that isn't wrapped in `FormProvider` — a create or edit
 * sheet. Widgets rendered here reach the form with `useHostForm()`, so fields
 * they bind save with the sheet's own submit.
 */
export function HostFormSlot<TContext extends object = object>({
  form,
  ...slot
}: SlotProps<TContext> & {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<any, any, any>
}) {
  return (
    <FormProvider {...form}>
      <Slot {...slot} />
    </FormProvider>
  )
}

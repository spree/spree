import type * as React from 'react'

import { cn } from '../lib/utils'

function Card({
  className,
  variant = 'default',
  ...props
}: React.ComponentProps<'div'> & {
  /**
   * `nested` is one resource listed inside a card — a fulfillment on an order,
   * a return, a rule. It sits on a recessed surface so it reads as a thing
   * *within* the card rather than another card beside it, and carries its own
   * horizontal padding so its sections divide edge to edge.
   *
   * The box is load-bearing once there is more than one of them: a fulfillment
   * already divides its own rows, so grouping by rules alone would draw the
   * boundary between two fulfillments as the same line at the same inset as
   * the boundary between two items — and the panel's own actions would have no
   * visible owner.
   *
   * `container` is the card those nested records sit in. Pair the two: the
   * container recedes, the records stay raised. A `default` card wrapping
   * `nested` ones puts the content in a well and the frame in front of it,
   * which reads as the content being demoted.
   */
  variant?: 'default' | 'nested' | 'container'
}) {
  return (
    <div
      data-slot="card"
      data-variant={variant}
      className={cn(
        // `overflow-x-clip`: a wide child (a table sized to its columns) otherwise
        // propagates its width up through every `overflow: visible` ancestor to
        // the document, laying the whole page out wider than the viewport. `clip`
        // rather than `hidden` so `overflow-y` stays `visible` and sticky
        // descendants keep resolving against the page.
        'group/card flex flex-col min-w-0 overflow-x-clip break-words text-card-foreground shadow-xs',
        variant === 'nested' && 'rounded-lg border border-border-subtle bg-nested-raised px-3',
        // Holds nested records rather than content, so it recedes and lets
        // them be the raised, readable thing.
        variant === 'container' && 'rounded-xl border border-border bg-card-container',
        variant === 'default' && 'rounded-xl border border-border bg-card',
        className,
      )}
      {...props}
    />
  )
}

function CardHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-header"
      className={cn(
        'group/card-header @container/card-header grid auto-rows-min items-start gap-1 group-data-[size=sm]/card:px-3 has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto] px-3 py-2.5 border-b border-border-subtle rounded-t-[calc(var(--radius-2xl)-1px)] group-data-[variant=nested]/card:rounded-none group-data-[variant=nested]/card:px-0 group-data-[variant=nested]/card:py-2 group-data-[variant=nested]/card:items-center',
        className,
      )}
      {...props}
    />
  )
}

function CardTitle({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-title"
      // Same size and weight as SheetTitle and DialogTitle: a card, a sheet
      // and a dialog heading are the same rank of thing.
      className={cn('text-base font-medium flex items-center gap-2', className)}
      {...props}
    />
  )
}

function CardDescription({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-description"
      className={cn('text-sm text-muted-foreground text-left', className)}
      {...props}
    />
  )
}

function CardAction({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="card-action" className={cn('ml-auto', className)} {...props} />
}

function CardContent({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-content"
      className={cn('p-3 group-data-[variant=nested]/card:px-0', className)}
      {...props}
    />
  )
}

function CardFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-footer"
      className={cn(
        'flex items-center p-3 bg-transparent border-t border-border-subtle rounded-b-[calc(var(--radius-xl)-1px)] group-data-[variant=nested]/card:rounded-none group-data-[variant=nested]/card:px-0',
        className,
      )}
      {...props}
    />
  )
}

export { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle }

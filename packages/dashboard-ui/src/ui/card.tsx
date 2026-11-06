import type * as React from 'react'

import { cn } from '../lib/utils'

function Card({
  className,
  variant = 'default',
  ...props
}: React.ComponentProps<'div'> & {
  /**
   * `nested` is one record in a list of them — a fulfillment, a return, a
   * rule — usually under a `Section` heading. It carries its own horizontal
   * padding so its header, sections and footer divide edge to edge.
   *
   * `container` is deprecated and renders as `default`: group records under
   * a `Section` heading instead of wrapping them in another card.
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
        'group/card flex flex-col min-w-0 overflow-x-clip break-words text-card-foreground',
        // An outline Item's frame and inset.
        variant === 'nested' &&
          'rounded-card border border-card-edge bg-card px-3.5 shadow-card-lift',
        // A faint border and a wide, soft lift (`--card-shadow`; none in
        // dark mode). `container` is deprecated and renders the same.
        variant !== 'nested' && 'rounded-card border border-card-edge bg-card shadow-card-lift',
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
        'group/card-header @container/card-header grid auto-rows-min items-start gap-1 group-data-[size=sm]/card:px-3 has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto] px-3.5 py-3 rounded-t-[calc(var(--radius-card)-1px)] group-data-[variant=nested]/card:rounded-none group-data-[variant=nested]/card:px-0 group-data-[variant=nested]/card:py-2 group-data-[variant=nested]/card:items-center',
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
      className={cn('text-base font-semibold flex items-center gap-2', className)}
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
      className={cn('p-3.5 group-data-[variant=nested]/card:px-0', className)}
      {...props}
    />
  )
}

function CardFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-footer"
      className={cn(
        'flex items-center p-3.5 bg-transparent border-t border-border-subtle rounded-b-[calc(var(--radius-card)-1px)] group-data-[variant=nested]/card:rounded-none group-data-[variant=nested]/card:px-0',
        className,
      )}
      {...props}
    />
  )
}

export { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle }

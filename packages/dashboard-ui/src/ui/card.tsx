import type * as React from 'react'

import { cn } from '../lib/utils'

function Card({
  className,
  variant: _variant,
  ...props
}: React.ComponentProps<'div'> & {
  /**
   * @deprecated Every card renders the same; the prop is accepted so plugin
   * code that passes it keeps compiling. Group records under a `Section`
   * heading, one plain card each, instead of nesting cards.
   */
  variant?: 'default' | 'nested' | 'container'
}) {
  return (
    <div
      data-slot="card"
      className={cn(
        // `overflow-x-clip`: a wide child (a table sized to its columns) otherwise
        // propagates its width up through every `overflow: visible` ancestor to
        // the document, laying the whole page out wider than the viewport. `clip`
        // rather than `hidden` so `overflow-y` stays `visible` and sticky
        // descendants keep resolving against the page.
        'group/card flex flex-col min-w-0 overflow-x-clip break-words text-card-foreground',
        // A faint border and a wide, soft lift (`--card-shadow`; none in
        // dark mode).
        'rounded-card border border-card-edge bg-card shadow-card-lift',
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
        'group/card-header @container/card-header grid auto-rows-min items-center gap-1 group-data-[size=sm]/card:px-3.5 has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto] mx-4 pt-3 pb-2 rounded-t-[calc(var(--radius-card)-1px)]',
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
      className={cn('text-base text-muted-foreground text-left', className)}
      {...props}
    />
  )
}

function CardAction({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="card-action" className={cn('ml-auto', className)} {...props} />
}

function CardContent({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="card-content" className={cn('p-4', className)} {...props} />
}

function CardFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-footer"
      className={cn(
        // Side margin, not padding, so the top rule stops short of the card's
        // edges and reads as a divider inside it.
        'mx-4 flex items-center py-4 bg-transparent border-t border-border-subtle',
        className,
      )}
      {...props}
    />
  )
}

export { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle }

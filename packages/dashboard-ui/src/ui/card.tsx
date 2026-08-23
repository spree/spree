import type * as React from 'react'

import { cn } from '../lib/utils'

function Card({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card"
      className={cn(
        // `overflow-x-clip`: a wide child (a table sized to its columns) otherwise
        // propagates its width up through every `overflow: visible` ancestor to
        // the document, laying the whole page out wider than the viewport. `clip`
        // rather than `hidden` so `overflow-y` stays `visible` and sticky
        // descendants keep resolving against the page.
        'group/card flex flex-col min-w-0 overflow-x-clip break-words bg-card text-card-foreground border border-border rounded-xl shadow-sm',
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
        'group/card-header @container/card-header grid auto-rows-min items-start gap-1 group-data-[size=sm]/card:px-3 has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto] px-3 py-2.5 border-b border-border-subtle rounded-t-[calc(var(--radius-2xl)-1px)]',
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
  return <div data-slot="card-content" className={cn('p-3', className)} {...props} />
}

function CardFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-footer"
      className={cn(
        'flex items-center p-3 bg-transparent border-t border-border-subtle rounded-b-[calc(var(--radius-xl)-1px)]',
        className,
      )}
      {...props}
    />
  )
}

export { Card, CardAction, CardContent, CardDescription, CardFooter, CardHeader, CardTitle }

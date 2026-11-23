import type * as React from 'react'
import { cn } from '../lib/utils'

/**
 * A titled group of cards on a page — an order's fulfillments, its returns.
 * The heading sits on the page with no frame of its own, and each record
 * below it is a card: a card inside a card would box the records twice.
 */
function Section({ className, ...props }: React.ComponentProps<'section'>) {
  return (
    <section
      data-slot="section"
      className={cn('flex min-w-0 flex-col gap-3', className)}
      {...props}
    />
  )
}

/** The heading row: a `SectionTitle`, then `SectionActions` at the end. */
function SectionHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="section-header"
      className={cn('flex min-h-8 flex-wrap items-center gap-2', className)}
      {...props}
    />
  )
}

/** A leading icon is set in a tile, so the heading reads as one without a frame. */
function SectionTitle({ className, ...props }: React.ComponentProps<'h2'>) {
  return (
    <h2
      data-slot="section-title"
      className={cn(
        'flex min-w-0 flex-1 items-center gap-2 font-semibold text-base',
        '[&>svg:first-child]:box-content [&>svg:first-child]:size-4 [&>svg:first-child]:shrink-0 [&>svg:first-child]:rounded-lg [&>svg:first-child]:bg-accent-strong [&>svg:first-child]:p-1.5',
        className,
      )}
      {...props}
    />
  )
}

function SectionActions({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="section-actions"
      className={cn('flex shrink-0 items-center gap-2', className)}
      {...props}
    />
  )
}

export { Section, SectionActions, SectionHeader, SectionTitle }

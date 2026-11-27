import type * as React from 'react'
import { cn } from '../lib/utils'

/**
 * A vertical history: a rail down the left, a marker on it per entry, the
 * entry's text beside it and its time on the right. Entries are grouped under
 * a date with `TimelineGroup`.
 *
 *   <Timeline>
 *     <TimelineGroup label="June 13, 2023">
 *       <TimelineItem time="3:37 PM">Payment of $20.00 captured</TimelineItem>
 *     </TimelineGroup>
 *   </Timeline>
 */
function Timeline({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="timeline"
      className={cn(
        'relative flex flex-col gap-6 pb-2',
        // The rail runs behind every marker, centred on the 1.5rem gutter.
        'before:absolute before:top-0 before:bottom-0 before:left-3 before:w-0.5 before:-translate-x-1/2 before:bg-border',
        className,
      )}
      {...props}
    />
  )
}

function TimelineGroup({
  label,
  className,
  children,
  ...props
}: React.ComponentProps<'section'> & { label: React.ReactNode }) {
  return (
    <section data-slot="timeline-group" className={cn('flex flex-col gap-4', className)} {...props}>
      <h3 className="pl-10 text-muted-foreground text-sm">{label}</h3>
      <ol className="flex flex-col gap-4">{children}</ol>
    </section>
  )
}

function TimelineItem({
  time,
  icon,
  className,
  children,
  ...props
}: Omit<React.ComponentProps<'li'>, 'title'> & {
  /** Shown on the right, aligned with the first line. */
  time?: React.ReactNode
  /** A small icon before the text, saying what kind of entry it is. */
  icon?: React.ReactNode
}) {
  return (
    <li
      data-slot="timeline-item"
      className={cn(
        'relative grid grid-cols-[1.5rem_minmax(0,1fr)_auto] gap-x-4 text-base',
        className,
      )}
      {...props}
    >
      <span className="flex h-6 items-center justify-center" aria-hidden>
        <span className="size-3 rounded-[0.25rem] bg-foreground ring-4 ring-background" />
      </span>
      <div className="flex min-w-0 gap-2">
        {icon && (
          <span className="flex size-6 shrink-0 items-center justify-center rounded-md bg-muted text-muted-foreground [&_svg]:size-3.5">
            {icon}
          </span>
        )}
        <div className="flex min-w-0 flex-1 flex-col gap-1.5 pt-0.5">{children}</div>
      </div>
      {time && <span className="pt-0.5 text-muted-foreground text-sm tabular-nums">{time}</span>}
    </li>
  )
}

export { Timeline, TimelineGroup, TimelineItem }

import { cn } from '../lib/utils'

function Skeleton({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="skeleton"
      // `accent`, not `muted`: muted sits ~1.5% off white, which reads as nothing
      // on a card. A skeleton has to be visible to do its job.
      className={cn('animate-pulse rounded-md bg-accent', className)}
      {...props}
    />
  )
}

export { Skeleton }

'use client'

import { Progress as ProgressPrimitive } from '@base-ui/react/progress'

import { cn } from '../lib/utils'

/**
 * Base UI progress bar. `value={null}` renders the indeterminate state
 * (Base UI stamps `data-indeterminate` on every part). Compose
 * `ProgressLabel`/`ProgressValue` as children when a caption is needed —
 * the track always renders last.
 */
function Progress({ className, children, value, ...props }: ProgressPrimitive.Root.Props) {
  return (
    <ProgressPrimitive.Root
      value={value}
      data-slot="progress"
      className={cn('flex w-full flex-wrap items-center gap-2', className)}
      {...props}
    >
      {children}
      <ProgressTrack>
        <ProgressIndicator />
      </ProgressTrack>
    </ProgressPrimitive.Root>
  )
}

function ProgressTrack({ className, ...props }: ProgressPrimitive.Track.Props) {
  return (
    <ProgressPrimitive.Track
      data-slot="progress-track"
      className={cn('relative h-2 w-full overflow-hidden rounded-full bg-primary/20', className)}
      {...props}
    />
  )
}

function ProgressIndicator({ className, ...props }: ProgressPrimitive.Indicator.Props) {
  return (
    <ProgressPrimitive.Indicator
      data-slot="progress-indicator"
      className={cn(
        // `width` is a layout property, but it's the right one here: a
        // determinate bar has to grow, and `scaleX` would distort the fill's
        // rounded ends. Narrowed from `transition-all` so only width animates.
        'h-full rounded-full bg-primary transition-[width] duration-200 ease-out',
        'data-[indeterminate]:w-1/3 data-[indeterminate]:animate-pulse',
        className,
      )}
      {...props}
    />
  )
}

function ProgressLabel({ className, ...props }: ProgressPrimitive.Label.Props) {
  return (
    <ProgressPrimitive.Label
      data-slot="progress-label"
      className={cn('font-medium text-sm', className)}
      {...props}
    />
  )
}

function ProgressValue({ className, ...props }: ProgressPrimitive.Value.Props) {
  return (
    <ProgressPrimitive.Value
      data-slot="progress-value"
      className={cn('ml-auto text-muted-foreground text-sm', className)}
      {...props}
    />
  )
}

export { Progress, ProgressIndicator, ProgressLabel, ProgressTrack, ProgressValue }

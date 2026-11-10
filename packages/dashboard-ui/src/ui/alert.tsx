import { cva, type VariantProps } from 'class-variance-authority'
import * as React from 'react'

import { cn } from '../lib/utils'

const alertVariants = cva(
  "group/alert relative grid w-full gap-0.5 rounded-card px-3.5 py-3 text-left text-sm has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-20 has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2.5 *:[svg]:row-span-2 *:[svg]:translate-y-0.5 *:[svg]:text-current *:[svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        // Borderless: the fill alone sets an alert apart. A plain note takes a
        // card's fill and lift, so it sits among the cards around it.
        default: 'bg-card text-card-foreground shadow-card-lift',
        // The status variants read off the badges' status ramps — their text
        // step over the ramp's quieter `surface` fill, which suits a block of
        // copy. Solid colours rather than one hue at an opacity, which
        // takes on whatever sits behind it and washes out on a dark card. The
        // description keeps the variant's colour, a little softer than the
        // title.
        destructive: 'bg-danger-surface text-danger *:data-[slot=alert-description]:text-danger/85',
        info: 'bg-info-surface text-info *:data-[slot=alert-description]:text-info/85',
        warning: 'bg-warning-surface text-warning *:data-[slot=alert-description]:text-warning/85',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
)

function Alert({
  className,
  variant,
  ...props
}: React.ComponentProps<'div'> & VariantProps<typeof alertVariants>) {
  return (
    <div
      data-slot="alert"
      role="alert"
      className={cn(alertVariants({ variant }), className)}
      {...props}
    />
  )
}

function AlertTitle({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="alert-title"
      className={cn(
        'font-semibold group-has-[>svg]/alert:col-start-2 [&_a]:text-link [&_a]:transition-colors [&_a]:hover:text-link-hover',
        className,
      )}
      {...props}
    />
  )
}

function AlertDescription({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="alert-description"
      className={cn(
        'text-sm text-balance text-muted-foreground md:text-pretty [&_a]:text-link [&_a]:transition-colors [&_a]:hover:text-link-hover [&_p:not(:last-child)]:mb-4',
        className,
      )}
      {...props}
    />
  )
}

function AlertAction({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="alert-action"
      className={cn('absolute top-2.5 right-3', className)}
      {...props}
    />
  )
}

export { Alert, AlertAction, AlertDescription, AlertTitle }

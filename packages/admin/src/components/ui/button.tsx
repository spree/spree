import { cva, type VariantProps } from 'class-variance-authority'
import type * as React from 'react'
import { Slot } from '@/components/ui/slot'

import { cn } from '@/lib/utils'

const buttonVariants = cva(
  "group/button inline-flex shrink-0 items-center justify-center gap-2 rounded-xl border border-transparent text-sm font-medium whitespace-nowrap cursor-pointer select-none no-underline transition-colors duration-100 ease-linear outline-none focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500 disabled:pointer-events-none disabled:opacity-70 disabled:cursor-not-allowed aria-invalid:border-destructive [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default:
          'bg-primary text-primary-foreground shadow-xs hover:bg-primary/85 dark:bg-blue-600 dark:text-white dark:hover:bg-blue-500',
        outline:
          'border-border bg-muted text-foreground shadow-xs hover:bg-accent hover:text-foreground aria-expanded:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground aria-expanded:bg-accent',
        destructive: 'text-destructive bg-muted border-border shadow-xs hover:bg-destructive/10',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-9 px-3 py-1.5',
        xs: "h-6 gap-1 rounded-lg px-2 text-xs [&_svg:not([class*='size-'])]:size-3",
        sm: "h-7 gap-1 rounded-lg px-2 py-1 text-sm [&_svg:not([class*='size-'])]:size-3.5",
        lg: 'h-10 px-3 py-2 text-base',
        icon: 'size-9',
        'icon-xs': "size-6 rounded-lg [&_svg:not([class*='size-'])]:size-3",
        'icon-sm': 'size-7 rounded-lg',
        'icon-lg': 'size-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  },
)

function Button({
  className,
  variant = 'default',
  size = 'default',
  asChild = false,
  ...props
}: React.ComponentProps<'button'> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot : 'button'

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }

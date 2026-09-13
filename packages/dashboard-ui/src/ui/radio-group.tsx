import { Radio as RadioPrimitive } from '@base-ui/react/radio'
import { RadioGroup as RadioGroupPrimitive } from '@base-ui/react/radio-group'
import type * as React from 'react'
import { cn } from '../lib/utils'

function RadioGroup({ className, ...props }: React.ComponentProps<typeof RadioGroupPrimitive>) {
  return (
    <RadioGroupPrimitive
      data-slot="radio-group"
      className={cn('grid w-full gap-2', className)}
      {...props}
    />
  )
}

function RadioGroupItem({ className, ...props }: React.ComponentProps<typeof RadioPrimitive.Root>) {
  return (
    <RadioPrimitive.Root
      data-slot="radio-group-item"
      className={cn(
        'peer relative inline-block size-4 shrink-0 cursor-pointer rounded-full border border-border bg-card align-[-3px] shadow-xs outline-none transition-[color,background-color,border-color,box-shadow] duration-100 ease-out',
        'focus:border-blue-500 focus:shadow-[0_0_0_3px_color-mix(in_srgb,var(--ring)_15%,transparent)]',
        'disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground disabled:shadow-none',
        'aria-invalid:border-destructive aria-invalid:ring-destructive/20',
        'data-[checked]:border-blue-500 data-[checked]:bg-blue-500 data-[checked]:text-white',
        'dark:aria-invalid:ring-destructive/40 dark:data-[checked]:bg-blue-500',
        className,
      )}
      {...props}
    >
      <RadioPrimitive.Indicator
        keepMounted
        data-slot="radio-group-indicator"
        className="absolute inset-0 flex items-center justify-center text-current transition-none data-[unchecked]:hidden"
      >
        <span className="size-1.5 rounded-full bg-current" />
      </RadioPrimitive.Indicator>
    </RadioPrimitive.Root>
  )
}

export { RadioGroup, RadioGroupItem }

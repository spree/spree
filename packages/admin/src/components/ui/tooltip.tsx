'use client'

import { Tooltip as TooltipPrimitive } from '@base-ui/react/tooltip'
import * as React from 'react'

import { cn } from '@/lib/utils'

function TooltipProvider({
  delayDuration = 0,
  children,
  ...props
}: {
  delayDuration?: number
  children: React.ReactNode
} & Omit<React.ComponentProps<typeof TooltipPrimitive.Provider>, 'delay'>) {
  return (
    <TooltipPrimitive.Provider data-slot="tooltip-provider" delay={delayDuration} {...props}>
      {children}
    </TooltipPrimitive.Provider>
  )
}

function Tooltip({
  children,
  ...props
}: {
  children?: React.ReactNode
  open?: boolean
  defaultOpen?: boolean
  onOpenChange?: (open: boolean, eventDetails: TooltipPrimitive.Root.ChangeEventDetails) => void
}) {
  return (
    <TooltipPrimitive.Root data-slot="tooltip" {...props}>
      {children}
    </TooltipPrimitive.Root>
  )
}

function TooltipTrigger({
  asChild,
  children,
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Trigger> & {
  asChild?: boolean
}) {
  if (asChild && React.isValidElement(children)) {
    return <TooltipPrimitive.Trigger data-slot="tooltip-trigger" render={children} {...props} />
  }

  return (
    <TooltipPrimitive.Trigger data-slot="tooltip-trigger" {...props}>
      {children}
    </TooltipPrimitive.Trigger>
  )
}

function TooltipContent({
  className,
  sideOffset = 4,
  side = 'top',
  align = 'center',
  children,
  hidden,
  ...props
}: {
  className?: string
  sideOffset?: number
  side?: 'top' | 'bottom' | 'left' | 'right'
  align?: 'start' | 'center' | 'end'
  children?: React.ReactNode
  hidden?: boolean
} & Omit<React.ComponentProps<typeof TooltipPrimitive.Popup>, 'className'>) {
  if (hidden) {
    return null
  }

  return (
    <TooltipPrimitive.Portal>
      <TooltipPrimitive.Positioner
        side={side}
        sideOffset={sideOffset}
        align={align}
        className="z-50"
      >
        <TooltipPrimitive.Popup
          data-slot="tooltip-content"
          className={cn(
            'z-50 inline-flex w-fit max-w-[200px] items-center gap-1.5 rounded-lg border border-border bg-popover px-2 py-1 text-sm font-normal text-popover-foreground shadow-md data-[starting-style]:opacity-0 data-[starting-style]:scale-95 data-[ending-style]:opacity-0 data-[ending-style]:scale-95 transition-[opacity,transform] duration-100',
            className,
          )}
          {...props}
        >
          {children}
        </TooltipPrimitive.Popup>
      </TooltipPrimitive.Positioner>
    </TooltipPrimitive.Portal>
  )
}

export { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger }

import { Tabs as TabsPrimitive } from '@base-ui/react/tabs'
import type * as React from 'react'
import { cn } from '../lib/utils'

function Tabs({
  className,
  orientation = 'horizontal',
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Root>) {
  return (
    <TabsPrimitive.Root
      data-slot="tabs"
      orientation={orientation}
      className={cn(
        'group/tabs flex gap-2 data-[orientation=horizontal]:flex-col data-[orientation=vertical]:flex-row',
        className,
      )}
      {...props}
    />
  )
}

/** The track a set of tabs sits in, recessed so the selected tab reads as raised. */
function TabsList({
  className,
  children,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.List>) {
  return (
    <TabsPrimitive.List
      data-slot="tabs-list"
      className={cn(
        'inline-flex w-fit items-center justify-center gap-1 rounded-lg bg-track-recessed p-1 text-muted-foreground',
        'group-data-[orientation=vertical]/tabs:h-auto group-data-[orientation=vertical]/tabs:w-full group-data-[orientation=vertical]/tabs:flex-col',
        className,
      )}
      {...props}
    >
      {children}
    </TabsPrimitive.List>
  )
}

function TabsTrigger({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.Tab>) {
  return (
    <TabsPrimitive.Tab
      data-slot="tabs-trigger"
      className={cn(
        // min-h-7 + py-1 keeps the hit area past the 24px WCAG target size at
        // every text size; the old h-[calc(100%-1px)] left it to the parent.
        'inline-flex min-h-7 flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-md px-2.5 py-1 text-sm font-medium whitespace-nowrap',
        'transition-[color,background-color,box-shadow] duration-150 ease-out outline-none motion-reduce:transition-none',
        'group-data-[orientation=vertical]/tabs:w-full group-data-[orientation=vertical]/tabs:justify-start',
        // Unselected tabs recede so the selected one reads as chosen; hover
        // promotes to full foreground rather than only shifting the surface,
        // which is the part a colour-blind or low-vision reader can see.
        'text-muted-foreground hover:text-foreground',
        // The raised surface lives on the tab itself, as it did before the
        // indicator: it is the thing that makes the selection legible, and it
        // must not depend on a separate element rendering correctly behind it.
        'data-[active]:bg-nested-raised data-[active]:text-foreground data-[active]:shadow-xs',
        // Same focus treatment as Button, so a keyboard user sees one
        // consistent indicator across the dashboard.
        'focus-visible:shadow-[0_0_0_3px_color-mix(in_srgb,var(--ring)_15%,transparent)]',
        'disabled:pointer-events-none disabled:opacity-70 disabled:cursor-not-allowed',
        "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className,
      )}
      {...props}
    />
  )
}

function TabsContent({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.Panel>) {
  return (
    <TabsPrimitive.Panel
      data-slot="tabs-content"
      className={cn('flex-1 outline-none', className)}
      {...props}
    />
  )
}

export { Tabs, TabsContent, TabsList, TabsTrigger }

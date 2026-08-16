'use client'

import { Tabs as TabsPrimitive } from '@base-ui/react/tabs'

import { cn } from '../lib/utils'

/**
 * Base UI tabs.
 *
 * Panels stay mounted (`keepMounted`) so a table's loaded page, scroll
 * position and in-flight polling survive a tab switch — remounting on every
 * switch is what makes tabbed admin screens feel like they lose your place.
 */
function Tabs({ className, ...props }: TabsPrimitive.Root.Props) {
  return (
    <TabsPrimitive.Root
      data-slot="tabs"
      className={cn('flex flex-col gap-4', className)}
      {...props}
    />
  )
}

function TabsList({ className, ...props }: TabsPrimitive.List.Props) {
  return (
    <TabsPrimitive.List
      data-slot="tabs-list"
      className={cn('relative flex items-center gap-1 border-b', className)}
      {...props}
    />
  )
}

/**
 * A tab. Pass `count` to append a tally — the number of steps outstanding, or
 * of records in the panel — which is what tells an operator whether a tab is
 * worth opening before they open it.
 */
function TabsTrigger({
  className,
  children,
  count,
  ...props
}: TabsPrimitive.Tab.Props & { count?: number }) {
  return (
    <TabsPrimitive.Tab
      data-slot="tabs-trigger"
      className={cn(
        'inline-flex items-center gap-2 whitespace-nowrap rounded-t-md px-3 py-2 font-medium text-muted-foreground text-sm',
        'transition-colors hover:text-foreground',
        'focus-visible:outline-2 focus-visible:outline-ring focus-visible:outline-offset-[-2px]',
        'data-[selected]:text-foreground',
        className,
      )}
      {...props}
    >
      {children}
      {count !== undefined && (
        <span className="rounded-full bg-muted px-1.5 py-0.5 text-xs tabular-nums">{count}</span>
      )}
    </TabsPrimitive.Tab>
  )
}

/** The moving underline beneath the selected tab. */
function TabsIndicator({ className, ...props }: TabsPrimitive.Indicator.Props) {
  return (
    <TabsPrimitive.Indicator
      data-slot="tabs-indicator"
      className={cn(
        'absolute bottom-0 left-0 h-0.5 w-[var(--active-tab-width)] bg-foreground',
        'translate-x-[var(--active-tab-left)] transition-[translate,width] duration-200 ease-out',
        className,
      )}
      {...props}
    />
  )
}

function TabsPanel({ className, ...props }: TabsPrimitive.Panel.Props) {
  return (
    <TabsPrimitive.Panel
      data-slot="tabs-panel"
      keepMounted
      className={cn('flex flex-col gap-4 focus-visible:outline-none', className)}
      {...props}
    />
  )
}

export { Tabs, TabsIndicator, TabsList, TabsPanel, TabsTrigger }

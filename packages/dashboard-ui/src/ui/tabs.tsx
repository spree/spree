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

/**
 * The track a set of tabs sits in, recessed so the selected tab reads as
 * raised. The raised pill is an indicator that slides between tabs; until it
 * has measured its tab, the selected tab draws the same pill itself.
 */
// The selected tab's surface: a flat white pill, set off from the track by
// its fill and a faint hairline rather than a drop shadow.
const TAB_RAISED =
  'bg-nested-raised shadow-[0_0_0_0.5px_rgb(0_0_0/0.05),0_1px_1px_rgb(0_0_0/0.03)] dark:shadow-[0_0_0_0.5px_rgb(255_255_255/0.06)]'

// Pills side by side; a vertical stack keeps rounded rectangles, which read
// better as a column.
const TAB_SHAPE = 'rounded-lg group-data-[orientation=vertical]/tabs:rounded-lg'

function TabsList({
  className,
  children,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.List>) {
  return (
    <TabsPrimitive.List
      data-slot="tabs-list"
      className={cn(
        'group/tabs-list relative inline-flex w-fit items-center justify-center gap-1 rounded-xl bg-track-recessed p-1 text-muted-foreground shadow-[inset_0_0_0_0.5px_rgb(0_0_0/0.04)] group-data-[orientation=vertical]/tabs:rounded-xl',
        'group-data-[orientation=vertical]/tabs:h-auto group-data-[orientation=vertical]/tabs:w-full group-data-[orientation=vertical]/tabs:flex-col',
        className,
      )}
      {...props}
    >
      <TabsPrimitive.Indicator
        data-slot="tabs-indicator"
        className={cn(
          TAB_RAISED,
          TAB_SHAPE,
          'absolute top-(--active-tab-top) left-(--active-tab-left) h-(--active-tab-height) w-(--active-tab-width)',
          // The switch's curve, so the two controls move alike.
          'transition-[left,top,width,height] duration-200 ease-[cubic-bezier(0.3,1.3,0.6,1)] motion-reduce:transition-none',
        )}
      />
      {children}
    </TabsPrimitive.List>
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
}: React.ComponentProps<typeof TabsPrimitive.Tab> & { count?: number }) {
  return (
    <TabsPrimitive.Tab
      data-slot="tabs-trigger"
      className={cn(
        // min-h-7 + py-1 keeps the hit area past the 24px WCAG target size at
        // every text size; the old h-[calc(100%-1px)] left it to the parent.
        'relative z-10 inline-flex min-h-7 flex-1 cursor-pointer items-center justify-center gap-1.5 px-3 py-1 text-sm font-medium whitespace-nowrap',
        'transition-[color,background-color,box-shadow] duration-150 ease-out outline-none motion-reduce:transition-none',
        TAB_SHAPE,
        'group-data-[orientation=vertical]/tabs:w-full group-data-[orientation=vertical]/tabs:justify-start',
        // Unselected tabs recede so the selected one reads as chosen; hover
        // promotes to full foreground rather than only shifting the surface,
        // which is the part a colour-blind or low-vision reader can see.
        // An unselected tab under the pointer fills one step under the track,
        // as a sidebar item does.
        'text-muted-foreground hover:text-foreground not-data-[active]:hover:bg-accent-strong',
        // The selected tab draws its own pill until the indicator has
        // measured it, so the selection never depends on that rendering;
        // then it turns clear and the sliding indicator shows through.
        cn(TAB_RAISED, 'not-data-[active]:bg-transparent not-data-[active]:shadow-none'),
        'data-[active]:text-foreground',
        'group-has-[>[data-slot=tabs-indicator]:not([hidden])]/tabs-list:bg-transparent group-has-[>[data-slot=tabs-indicator]:not([hidden])]/tabs-list:shadow-none',
        // Same focus treatment as Button, so a keyboard user sees one
        // consistent indicator across the dashboard.
        'focus-visible:shadow-[0_0_0_3px_color-mix(in_srgb,var(--ring)_15%,transparent)]',
        'disabled:pointer-events-none disabled:opacity-70 disabled:cursor-not-allowed',
        "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className,
      )}
      {...props}
    >
      {children}
      {count !== undefined && (
        <span className="rounded-lg bg-accent-strong-hover px-1.5 py-0.5 text-xs text-foreground tabular-nums">
          {count}
        </span>
      )}
    </TabsPrimitive.Tab>
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

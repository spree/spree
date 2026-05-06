import { ChevronLeftIcon, ChevronRightIcon } from 'lucide-react'
import type * as React from 'react'
import { DayPicker } from 'react-day-picker'
import { cn } from '@/lib/utils'

function Calendar({
  className,
  classNames,
  showOutsideDays = true,
  ...props
}: React.ComponentProps<typeof DayPicker>) {
  return (
    <DayPicker
      showOutsideDays={showOutsideDays}
      className={cn('p-3', className)}
      classNames={{
        months: 'flex flex-col sm:flex-row gap-2 relative',
        month: 'flex flex-col gap-4',
        month_caption: 'flex justify-center pt-1 relative items-center w-full',
        caption_label: 'text-sm font-medium',
        nav: 'absolute top-1 inset-x-0 flex items-center justify-between px-1 z-10',
        button_previous:
          'inline-flex size-7 items-center justify-center rounded-md border border-border bg-transparent p-0 text-muted-foreground transition-colors hover:bg-accent hover:text-foreground',
        button_next:
          'inline-flex size-7 items-center justify-center rounded-md border border-border bg-transparent p-0 text-muted-foreground transition-colors hover:bg-accent hover:text-foreground',
        month_grid: 'w-full border-collapse',
        weekdays: 'flex',
        weekday: 'text-muted-foreground rounded-md w-8 font-normal text-xs',
        week: 'flex w-full mt-2',
        day: 'relative p-0 text-center text-sm focus-within:relative focus-within:z-20 [&:has([aria-selected])]:bg-blue-50 [&:has([aria-selected].day-outside)]:bg-blue-50/50 [&:has([aria-selected].day-range-end)]:rounded-r-md',
        day_button: cn(
          'inline-flex size-8 items-center justify-center rounded-md p-0 font-normal transition-colors',
          'hover:bg-accent hover:text-foreground',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500',
          'aria-selected:bg-blue-600 aria-selected:text-white aria-selected:hover:bg-blue-700 aria-selected:focus:bg-blue-700',
        ),
        range_start: 'day-range-start rounded-l-md',
        range_end: 'day-range-end rounded-r-md',
        selected: 'bg-blue-600 text-white hover:bg-blue-700 focus:bg-blue-700',
        today: 'bg-accent text-foreground',
        outside:
          'day-outside text-muted-foreground opacity-50 aria-selected:bg-blue-500/15 aria-selected:text-muted-foreground aria-selected:opacity-60',
        disabled: 'text-muted-foreground opacity-50',
        range_middle: 'aria-selected:bg-blue-500/15 aria-selected:text-foreground',
        hidden: 'invisible',
        ...classNames,
      }}
      components={{
        Chevron: ({ orientation }) =>
          orientation === 'left' ? (
            <ChevronLeftIcon className="size-4" />
          ) : (
            <ChevronRightIcon className="size-4" />
          ),
      }}
      {...props}
    />
  )
}

export { Calendar }

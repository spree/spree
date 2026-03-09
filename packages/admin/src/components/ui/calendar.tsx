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
        months: 'flex flex-col sm:flex-row gap-2',
        month: 'flex flex-col gap-4',
        month_caption: 'flex justify-center pt-1 relative items-center w-full',
        caption_label: 'text-sm font-medium',
        nav: 'flex items-center gap-1',
        button_previous:
          'absolute left-1 top-0 inline-flex size-7 items-center justify-center rounded-md border border-gray-200 bg-transparent p-0 text-gray-600 opacity-50 hover:opacity-100 transition-opacity',
        button_next:
          'absolute right-1 top-0 inline-flex size-7 items-center justify-center rounded-md border border-gray-200 bg-transparent p-0 text-gray-600 opacity-50 hover:opacity-100 transition-opacity',
        month_grid: 'w-full border-collapse',
        weekdays: 'flex',
        weekday: 'text-muted-foreground rounded-md w-8 font-normal text-xs',
        week: 'flex w-full mt-2',
        day: 'relative p-0 text-center text-sm focus-within:relative focus-within:z-20 [&:has([aria-selected])]:bg-blue-50 [&:has([aria-selected].day-outside)]:bg-blue-50/50 [&:has([aria-selected].day-range-end)]:rounded-r-md',
        day_button: cn(
          'inline-flex size-8 items-center justify-center rounded-md p-0 font-normal transition-colors',
          'hover:bg-gray-100 hover:text-gray-950',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500',
          'aria-selected:bg-blue-600 aria-selected:text-white aria-selected:hover:bg-blue-700 aria-selected:focus:bg-blue-700',
        ),
        range_end: 'day-range-end rounded-r-md',
        selected: 'bg-blue-600 text-white hover:bg-blue-700 focus:bg-blue-700',
        today: 'bg-gray-100 text-gray-950',
        outside:
          'day-outside text-muted-foreground opacity-50 aria-selected:bg-blue-50 aria-selected:text-muted-foreground aria-selected:opacity-30',
        disabled: 'text-muted-foreground opacity-50',
        range_middle: 'aria-selected:bg-blue-50 aria-selected:text-gray-950',
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

import { addMonths, startOfMonth, subMonths } from 'date-fns'
import { useState } from 'react'
import type { DateRange as DayPickerDateRange } from 'react-day-picker'
import { useIsMobile } from '../hooks/use-mobile'
import { cn } from '../lib/utils'
import { CheckIcon } from '../spree/icons'
import { Calendar } from './calendar'

export interface DateRangePanelPreset<K extends string = string> {
  key: K
  label: string
}

export interface DateRangePanelProps<K extends string> {
  presets: DateRangePanelPreset<K>[]
  /** The preset the applied range matches, if any. */
  activePreset?: string | null
  /** Picking a preset applies it straight away; the caller closes the popover. */
  onPresetSelect: (key: K) => void
  /** Seeds the calendar's highlight. */
  initialRange?: DayPickerDateRange
  /** Called once a picked range has both ends; the caller closes the popover. */
  onApply: (range: { from: Date; to: Date }) => void
}

/**
 * Popover body for picking a date range: named ranges on the left, a range
 * calendar on the right. Mount it inside a popover's content so it reseeds
 * from `initialRange` each time it opens.
 */
export function DateRangePanel<K extends string>({
  presets,
  activePreset,
  onPresetSelect,
  initialRange,
  onApply,
}: DateRangePanelProps<K>) {
  const isMobile = useIsMobile()
  const months = isMobile ? 1 : 2
  const [range, setRange] = useState<DayPickerDateRange | undefined>(initialRange)
  // A click starts a new range and the next one ends and applies it, the way
  // a preset applies on click; the same day twice picks that one day. DayPicker's own
  // selection moves the nearest end of the applied range instead, so picking
  // the 10th and then the 12th over "Last 30 days" kept its start.
  const [pickingEnd, setPickingEnd] = useState(false)

  function pickDay(day: Date) {
    if (pickingEnd && range?.from) {
      const picked =
        day < range.from ? { from: day, to: range.from } : { from: range.from, to: day }
      setRange(picked)
      setPickingEnd(false)
      onApply(picked)
    } else {
      setRange({ from: day, to: day })
      setPickingEnd(true)
    }
  }
  // The last month shown, so a range ending today keeps this month in view
  // whether one month shows or two.
  const [endMonth, setEndMonth] = useState(() =>
    startOfMonth(initialRange?.to ?? initialRange?.from ?? new Date()),
  )

  return (
    // Phones get the full popover width: the presets as a list, then one
    // month with finger-sized days. Wider screens put them side by side.
    <div className="flex w-[min(calc(100vw-2rem),24rem)] flex-col md:w-auto md:flex-row">
      <div className="flex flex-col gap-0.5 border-b p-2 md:w-44 md:border-r md:border-b-0">
        {presets.map((preset) => {
          const active = preset.key === activePreset
          return (
            <button
              key={preset.key}
              type="button"
              aria-pressed={active}
              onClick={() => onPresetSelect(preset.key)}
              className={cn(
                'flex items-center justify-between gap-2 whitespace-nowrap rounded-lg px-3 py-2.5 text-left text-sm md:px-2.5 md:py-1.5 transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50',
                active ? 'bg-accent font-medium text-foreground' : 'text-muted-foreground',
              )}
            >
              {preset.label}
              {active && <CheckIcon className="size-3.5 shrink-0" />}
            </button>
          )
        })}
      </div>
      <div className="flex flex-col p-3">
        <Calendar
          className="max-md:mx-auto max-md:[&_td>button]:size-10 max-md:[&_th]:w-10"
          mode="range"
          month={subMonths(endMonth, months - 1)}
          onMonthChange={(first) => setEndMonth(addMonths(first, months - 1))}
          selected={range}
          onSelect={(_next, day) => pickDay(day)}
          numberOfMonths={months}
        />
      </div>
    </div>
  )
}

import { format } from 'date-fns'
import { useMemo, useState } from 'react'
import type { DateRange as DayPickerDateRange } from 'react-day-picker'
import { useTranslation } from 'react-i18next'
import { activeDateLocale } from '../lib/date-locale'
import {
  DATE_RANGE_PRESET_KEYS,
  type DateRangePresetKey,
  matchDateRangePreset,
  resolveDateRangePreset,
} from '../lib/date-range-presets'
import { cn } from '../lib/utils'
import { CalendarIcon, ChevronDownIcon } from '../spree/icons'
import { Button } from './button'
import { Calendar } from './calendar'
import { Popover, PopoverContent, PopoverTrigger } from './popover'

export interface DateRange {
  from: Date
  to: Date
}

const PRESET_LABEL_KEYS: Record<Exclude<DateRangePresetKey, 'custom'>, string> = {
  '7d': 'admin.components.date_range_picker.presets.last_7_days',
  '14d': 'admin.components.date_range_picker.presets.last_14_days',
  '30d': 'admin.components.date_range_picker.presets.last_30_days',
  '90d': 'admin.components.date_range_picker.presets.last_90_days',
  this_month: 'admin.components.date_range_picker.presets.this_month',
  ytd: 'admin.components.date_range_picker.presets.year_to_date',
}

export interface DateRangePickerProps {
  value: DateRange
  onChange: (range: DateRange) => void
  /**
   * IANA timezone used to resolve relative presets ("last 30 days").
   * Defaults to the browser zone. Pass the store timezone on admin
   * surfaces so every merchant sees the same span.
   */
  timezone?: string
}

export function DateRangePicker({ value, onChange, timezone }: DateRangePickerProps) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [calendarRange, setCalendarRange] = useState<DayPickerDateRange | undefined>()
  const [month, setMonth] = useState<Date>(value.from)

  const zone = useMemo(
    () => timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC',
    [timezone],
  )
  // Derived from `value` so a remount — or a range written by the parent —
  // keeps the trigger and the highlighted preset in sync. A second piece of
  // preset state is what made "Last 90 days" revert to "Last 30 days"
  // after the dashboard swapped the picker for a skeleton.
  const activePreset = matchDateRangePreset(value, zone)

  const dateLocale = activeDateLocale()
  const triggerLabel =
    activePreset === 'custom'
      ? `${format(value.from, 'MMM d', { locale: dateLocale })} – ${format(value.to, 'MMM d', { locale: dateLocale })}`
      : t(PRESET_LABEL_KEYS[activePreset])

  function selectPreset(key: Exclude<DateRangePresetKey, 'custom'>) {
    const range = resolveDateRangePreset(key, zone)
    setCalendarRange({ from: range.from, to: range.to })
    setMonth(range.from)
    onChange(range)
    setOpen(false)
  }

  function applyCustomRange() {
    if (calendarRange?.from && calendarRange?.to) {
      onChange({ from: calendarRange.from, to: calendarRange.to })
      setOpen(false)
    }
  }

  const canApply = calendarRange?.from && calendarRange?.to

  return (
    <Popover
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen)
        if (nextOpen) {
          setCalendarRange({ from: value.from, to: value.to })
          setMonth(value.from)
        }
      }}
    >
      <PopoverTrigger asChild>
        <Button size="sm" variant="outline" className="h-8 gap-2 text-sm font-normal">
          <CalendarIcon className="size-3.5" />
          {triggerLabel}
          <ChevronDownIcon className="size-3.5 text-muted-foreground" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-auto p-0">
        <div className="flex">
          <div className="flex flex-col border-r py-2">
            {DATE_RANGE_PRESET_KEYS.map((key) => (
              <button
                key={key}
                type="button"
                onClick={() => selectPreset(key)}
                className={cn(
                  'whitespace-nowrap px-4 py-1.5 text-left text-sm transition-colors hover:bg-accent',
                  activePreset === key && 'font-medium text-foreground',
                  activePreset !== key && 'text-muted-foreground',
                )}
              >
                {t(PRESET_LABEL_KEYS[key])}
              </button>
            ))}
          </div>
          <div className="flex flex-col p-3">
            <Calendar
              mode="range"
              month={month}
              onMonthChange={setMonth}
              selected={calendarRange}
              onSelect={setCalendarRange}
              numberOfMonths={2}
            />
            <div className="flex justify-end border-t pt-3">
              <Button size="sm" disabled={!canApply} onClick={applyCustomRange}>
                {t('admin.actions.apply')}
              </Button>
            </div>
          </div>
        </div>
      </PopoverContent>
    </Popover>
  )
}

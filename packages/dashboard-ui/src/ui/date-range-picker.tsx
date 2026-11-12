import { format } from 'date-fns'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { activeDateLocale } from '../lib/date-locale'
import {
  DATE_RANGE_PRESET_KEYS,
  type DateRangePresetKey,
  matchDateRangePreset,
  resolveDateRangePreset,
} from '../lib/date-range-presets'
import { fieldTriggerClassName } from '../lib/field-trigger'
import { cn } from '../lib/utils'
import { CalendarIcon, ChevronsUpDownIcon } from '../spree/icons'
import { DateRangePanel } from './date-range-panel'
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

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        {/* Field-shaped like the select and combobox triggers it sits beside. */}
        <button
          type="button"
          data-size="sm"
          className={cn(fieldTriggerClassName, 'w-auto shrink-0 whitespace-nowrap')}
        >
          <span className="flex items-center gap-2">
            <CalendarIcon className="size-3.5" />
            {triggerLabel}
          </span>
          <ChevronsUpDownIcon className="size-3.5 text-muted-foreground" />
        </button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-auto max-w-[calc(100vw-1rem)] p-0">
        <DateRangePanel
          // Reseeds the calendar whenever the applied range changes, even if
          // the popover reopens before its closing animation unmounts it.
          key={`${value.from.getTime()}:${value.to.getTime()}`}
          presets={DATE_RANGE_PRESET_KEYS.map((key) => ({ key, label: t(PRESET_LABEL_KEYS[key]) }))}
          activePreset={activePreset}
          onPresetSelect={(key) => {
            onChange(resolveDateRangePreset(key, zone))
            setOpen(false)
          }}
          initialRange={{ from: value.from, to: value.to }}
          onApply={(range) => {
            onChange(range)
            setOpen(false)
          }}
        />
      </PopoverContent>
    </Popover>
  )
}

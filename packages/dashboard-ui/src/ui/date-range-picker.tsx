import { format, startOfMonth, startOfYear, subDays } from 'date-fns'
import { CalendarIcon, ChevronDownIcon } from 'lucide-react'
import { useState } from 'react'
import type { DateRange as DayPickerDateRange } from 'react-day-picker'
import { useTranslation } from 'react-i18next'
import { activeDateLocale } from '../lib/date-locale'
import { cn } from '../lib/utils'
import { Button } from './button'
import { Calendar } from './calendar'
import { Popover, PopoverContent, PopoverTrigger } from './popover'

export interface DateRange {
  from: Date
  to: Date
}

type PresetKey = '7d' | '14d' | '30d' | '90d' | 'this_month' | 'ytd' | 'custom'

interface Preset {
  key: PresetKey
  labelKey: string
  value: () => DateRange
}

const presets: Preset[] = [
  {
    key: '7d',
    labelKey: 'admin.components.date_range_picker.presets.last_7_days',
    value: () => ({ from: subDays(new Date(), 7), to: new Date() }),
  },
  {
    key: '14d',
    labelKey: 'admin.components.date_range_picker.presets.last_14_days',
    value: () => ({ from: subDays(new Date(), 14), to: new Date() }),
  },
  {
    key: '30d',
    labelKey: 'admin.components.date_range_picker.presets.last_30_days',
    value: () => ({ from: subDays(new Date(), 30), to: new Date() }),
  },
  {
    key: '90d',
    labelKey: 'admin.components.date_range_picker.presets.last_90_days',
    value: () => ({ from: subDays(new Date(), 90), to: new Date() }),
  },
  {
    key: 'this_month',
    labelKey: 'admin.components.date_range_picker.presets.this_month',
    value: () => ({ from: startOfMonth(new Date()), to: new Date() }),
  },
  {
    key: 'ytd',
    labelKey: 'admin.components.date_range_picker.presets.year_to_date',
    value: () => ({ from: startOfYear(new Date()), to: new Date() }),
  },
]

interface DateRangePickerProps {
  value: DateRange
  onChange: (range: DateRange) => void
}

export function DateRangePicker({ value, onChange }: DateRangePickerProps) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [activePreset, setActivePreset] = useState<PresetKey>('30d')
  const [calendarRange, setCalendarRange] = useState<DayPickerDateRange | undefined>()

  const activePresetLabelKey =
    presets.find((p) => p.key === activePreset)?.labelKey ??
    'admin.components.date_range_picker.presets.last_30_days'

  const dateLocale = activeDateLocale()
  const triggerLabel =
    activePreset === 'custom'
      ? `${format(value.from, 'MMM d', { locale: dateLocale })} – ${format(value.to, 'MMM d', { locale: dateLocale })}`
      : t(activePresetLabelKey)

  function selectPreset(preset: Preset) {
    const range = preset.value()
    setActivePreset(preset.key)
    setCalendarRange({ from: range.from, to: range.to })
    onChange(range)
    setOpen(false)
  }

  function applyCustomRange() {
    if (calendarRange?.from && calendarRange?.to) {
      setActivePreset('custom')
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
            {presets.map((preset) => (
              <button
                key={preset.key}
                type="button"
                onClick={() => selectPreset(preset)}
                className={cn(
                  'whitespace-nowrap px-4 py-1.5 text-left text-sm transition-colors hover:bg-accent',
                  activePreset === preset.key && 'font-medium text-foreground',
                  activePreset !== preset.key && 'text-muted-foreground',
                )}
              >
                {t(preset.labelKey)}
              </button>
            ))}
          </div>
          <div className="flex flex-col p-3">
            <Calendar
              mode="range"
              defaultMonth={calendarRange?.from}
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

import { format, parse, parseISO } from 'date-fns'
import { formatInTimeZone, fromZonedTime, toZonedTime } from 'date-fns-tz'
import { CalendarIcon, XIcon } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Calendar } from '@/components/ui/calendar'
import { Input } from '@/components/ui/input'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { i18n } from '@/lib/i18n'
import { cn } from '@/lib/utils'

interface DatePickerProps {
  value?: string | null
  onChange?: (value: string | null) => void
  placeholder?: string
  className?: string
  disabled?: boolean
  includeTime?: boolean
  /**
   * IANA timezone (e.g. `Europe/Berlin`) used to interpret datetime values.
   * Defaults to the browser's resolved timezone. **Pass the store timezone
   * for any admin-facing surface** so that wall-clock times mean the same
   * thing for every admin regardless of where they're logged in from. Use
   * `<StoreDatePicker>` (in `components/spree/`) to do this automatically.
   *
   * Date-only mode (`includeTime=false`) is timezone-agnostic — values are
   * plain `yyyy-MM-dd` strings with no clock component.
   */
  timezone?: string
  /**
   * Render the calendar panel inline (absolute-positioned beneath the
   * trigger) instead of via Base UI's `<Popover>` Portal. Set this on any
   * usage nested inside a `<Sheet>` — Base UI's Popover Portal silently
   * fails to mount inside deeply nested portal trees, so callers in form
   * sheets / edit drawers must opt in. Filter panels and page-level forms
   * keep the default Popover behavior.
   */
  inline?: boolean
}

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/

// Parse the inbound value into a Date whose **browser-local components**
// match the *store-local* date/time the value represents:
// - `yyyy-MM-dd` (date-only): timezone-agnostic; parse in browser-local.
// - Full ISO timestamp (datetime): UTC instant reinterpreted in store TZ.
function parseValue(value: string | null | undefined, tz: string): Date | undefined {
  if (!value) return undefined
  if (DATE_ONLY.test(value)) return parse(value, 'yyyy-MM-dd', new Date())
  return toZonedTime(parseISO(value), tz)
}

// Format the value for the trigger button. Date-only uses the locally-anchored
// Date; datetime uses store-TZ formatting on the original UTC instant.
function formatTriggerLabel(
  value: string | null | undefined,
  date: Date | undefined,
  tz: string,
  includeTime: boolean,
  placeholder: string,
): string {
  if (!date || Number.isNaN(date.getTime())) return placeholder
  if (includeTime && value && !DATE_ONLY.test(value)) {
    return formatInTimeZone(parseISO(value), tz, 'PPP p')
  }
  return format(date, includeTime ? 'PPP p' : 'PPP')
}

function DatePicker({
  value,
  onChange,
  placeholder = 'Pick a date',
  className,
  disabled = false,
  includeTime = false,
  timezone,
  inline = false,
}: DatePickerProps) {
  const [open, setOpen] = useState(false)
  const containerRef = useRef<HTMLDivElement | null>(null)

  // Browser TZ is the fallback — used in non-admin contexts (Storybook,
  // isolated tests) where there's no store context to pull from.
  const tz = useMemo(
    () => timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC',
    [timezone],
  )

  // The Calendar and trigger label both read browser-local components, so
  // anchoring them to store-local wall-clock is what makes the UI correct.
  const date = useMemo(() => parseValue(value, tz), [value, tz])
  const isValidDate = !!date && !Number.isNaN(date.getTime())

  // Inline mode only: close on outside pointerdown / Escape. Popover mode
  // gets this behavior from Base UI.
  useEffect(() => {
    if (!inline || !open) return
    function handle(event: PointerEvent) {
      const target = event.target as Node | null
      if (!target || !containerRef.current) return
      if (!containerRef.current.contains(target)) setOpen(false)
    }
    function handleKey(event: KeyboardEvent) {
      if (event.key === 'Escape') setOpen(false)
    }
    document.addEventListener('pointerdown', handle)
    document.addEventListener('keydown', handleKey)
    return () => {
      document.removeEventListener('pointerdown', handle)
      document.removeEventListener('keydown', handleKey)
    }
  }, [inline, open])

  const handleSelect = (selected: Date | undefined) => {
    if (!selected) {
      onChange?.(null)
      return
    }

    if (!includeTime) {
      // Date-only: emit `yyyy-MM-dd` using browser-local components. The
      // user clicked a specific calendar day; the day number is what
      // matters, not the timezone.
      onChange?.(format(selected, 'yyyy-MM-dd'))
      setOpen(false)
      return
    }

    // Datetime: the picked Date has browser-local components for the
    // selected day at (preserved or zero) hours/minutes. Reinterpret those
    // wall-clock components as **store-local time**, then emit the UTC
    // instant. `fromZonedTime` does exactly this conversion.
    if (date && isValidDate) {
      selected.setHours(date.getHours(), date.getMinutes())
    }
    onChange?.(fromZonedTime(selected, tz).toISOString())
  }

  const handleTimeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const raw = e.target.value
    if (!raw) {
      onChange?.(null)
      return
    }
    const [hours, minutes] = raw.split(':').map(Number)
    if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return
    const d = date && isValidDate ? new Date(date) : new Date()
    d.setHours(hours, minutes, 0, 0)
    onChange?.(fromZonedTime(d, tz).toISOString())
  }

  const handleClear = (e: React.SyntheticEvent) => {
    e.preventDefault()
    e.stopPropagation()
    onChange?.(null)
  }

  const timeValue = useMemo(
    () =>
      isValidDate && date
        ? `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
        : '',
    [isValidDate, date],
  )

  const triggerLabel = useMemo(
    () => formatTriggerLabel(value, date, tz, includeTime, placeholder),
    [value, date, tz, includeTime, placeholder],
  )

  const triggerChildren = (
    <>
      <CalendarIcon className="size-4 shrink-0 text-muted-foreground" />
      <span className="flex-1 truncate">{triggerLabel}</span>
      {isValidDate && (
        <span
          role="button"
          tabIndex={0}
          aria-label={i18n.t('admin.a11y.clear_date')}
          className="inline-flex size-4 items-center justify-center rounded-sm text-muted-foreground hover:text-foreground transition-colors cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          onClick={handleClear}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') handleClear(e)
          }}
        >
          <XIcon className="size-3.5" />
        </span>
      )}
    </>
  )

  const panelChildren = (
    <>
      <Calendar
        mode="single"
        selected={isValidDate ? date : undefined}
        onSelect={handleSelect}
        defaultMonth={isValidDate ? date : undefined}
      />
      {includeTime && (
        <div className="border-t border-border px-3 py-2">
          <Input type="time" value={timeValue} onChange={handleTimeChange} />
        </div>
      )}
    </>
  )

  if (inline) {
    return (
      <div ref={containerRef} className={cn('relative', className)}>
        <Button
          type="button"
          variant="outline"
          data-empty={!isValidDate}
          disabled={disabled}
          aria-haspopup="dialog"
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
          className="w-full justify-start"
        >
          {triggerChildren}
        </Button>
        {open && (
          <div
            role="dialog"
            aria-label={placeholder}
            className="absolute top-full left-0 z-50 mt-2 w-auto rounded-lg border border-border bg-popover p-0 text-popover-foreground shadow-md"
          >
            {panelChildren}
          </div>
        )}
      </div>
    )
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild disabled={disabled}>
        <Button type="button" variant="outline" data-empty={!isValidDate} className={className}>
          {triggerChildren}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
        {panelChildren}
      </PopoverContent>
    </Popover>
  )
}

export type { DatePickerProps }
export { DatePicker }

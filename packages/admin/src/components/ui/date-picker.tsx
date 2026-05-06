import { format, parseISO } from 'date-fns'
import { CalendarIcon, XIcon } from 'lucide-react'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Calendar } from '@/components/ui/calendar'
import { Input } from '@/components/ui/input'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'

interface DatePickerProps {
  value?: string | null
  onChange?: (value: string | null) => void
  placeholder?: string
  className?: string
  disabled?: boolean
  includeTime?: boolean
}

function DatePicker({
  value,
  onChange,
  placeholder = 'Pick a date',
  className: _,
  disabled = false,
  includeTime = false,
}: DatePickerProps) {
  const [open, setOpen] = useState(false)

  const date = value ? parseISO(value) : undefined
  const isValidDate = date && !Number.isNaN(date.getTime())

  const handleSelect = (selected: Date | undefined) => {
    if (!selected) {
      onChange?.(null)
      return
    }

    if (includeTime && isValidDate) {
      // Preserve existing time when changing date
      selected.setHours(date.getHours(), date.getMinutes())
    }

    onChange?.(selected.toISOString())
    if (!includeTime) setOpen(false)
  }

  const handleTimeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const [hours, minutes] = e.target.value.split(':').map(Number)
    const d = isValidDate ? new Date(date) : new Date()
    d.setHours(hours, minutes, 0, 0)
    onChange?.(d.toISOString())
  }

  const handleClear = (e: React.MouseEvent) => {
    e.stopPropagation()
    onChange?.(null)
  }

  const timeValue = isValidDate
    ? `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
    : ''

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild disabled={disabled}>
        <Button type="button" variant="outline" data-empty={!isValidDate}>
          <CalendarIcon className="size-4 shrink-0 text-muted-foreground" />
          <span className="flex-1 truncate">
            {isValidDate ? format(date, includeTime ? 'PPP p' : 'PPP') : placeholder}
          </span>
          {isValidDate && (
            <span
              role="button"
              tabIndex={-1}
              className="inline-flex size-4 items-center justify-center rounded-sm text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
              onPointerDown={handleClear}
            >
              <XIcon className="size-3.5" />
            </span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
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
      </PopoverContent>
    </Popover>
  )
}

export type { DatePickerProps }
export { DatePicker }

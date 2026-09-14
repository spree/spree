import { format, startOfMonth, startOfYear, subDays } from 'date-fns'
import { toZonedTime } from 'date-fns-tz'

/**
 * Named ranges the date-range picker offers. `custom` is a hand-picked
 * span that no named entry produces today.
 */
export type DateRangePresetKey = '7d' | '14d' | '30d' | '90d' | 'this_month' | 'ytd' | 'custom'

export const DATE_RANGE_PRESET_KEYS: Exclude<DateRangePresetKey, 'custom'>[] = [
  '7d',
  '14d',
  '30d',
  '90d',
  'this_month',
  'ytd',
]

export interface CalendarDateRange {
  from: Date
  to: Date
}

/**
 * Resolve a named range on the given calendar.
 *
 * "Last N days" is inclusive of today — last 30 days is 30 dates, so the
 * start is 29 days back. The timezone argument is the merchant's zone:
 * these ranges are relative to *now* where they trade, not where the
 * browser happens to be.
 */
export function resolveDateRangePreset(
  preset: Exclude<DateRangePresetKey, 'custom'>,
  timezone: string,
): CalendarDateRange {
  const now = toZonedTime(new Date(), timezone)

  switch (preset) {
    case '7d':
      return { from: subDays(now, 6), to: now }
    case '14d':
      return { from: subDays(now, 13), to: now }
    case '30d':
      return { from: subDays(now, 29), to: now }
    case '90d':
      return { from: subDays(now, 89), to: now }
    case 'this_month':
      return { from: startOfMonth(now), to: now }
    case 'ytd':
      return { from: startOfYear(now), to: now }
  }
}

/**
 * Recognise which named range a pair of dates came from, so a picker that
 * remounts (or is given a range from outside) re-selects its menu entry
 * instead of always reading as the default.
 *
 * Matching by calendar day rather than storing the key keeps the value a
 * plain range — the preset is a way of writing dates, not a second piece
 * of state that can drift. A range that no longer matches any preset
 * (yesterday's "last 7 days", reopened today) correctly reads as custom.
 */
export function matchDateRangePreset(
  range: CalendarDateRange,
  timezone: string,
): DateRangePresetKey {
  const from = dayKey(range.from)
  const to = dayKey(range.to)
  for (const key of DATE_RANGE_PRESET_KEYS) {
    const candidate = resolveDateRangePreset(key, timezone)
    if (dayKey(candidate.from) === from && dayKey(candidate.to) === to) return key
  }
  return 'custom'
}

function dayKey(date: Date): string {
  return format(date, 'yyyy-MM-dd')
}

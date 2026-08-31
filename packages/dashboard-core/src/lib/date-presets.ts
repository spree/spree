import { format, startOfMonth, subDays, subMonths } from 'date-fns'
import { toZonedTime } from 'date-fns-tz'

/**
 * Relative date ranges offered by the toolbar's quick date filter.
 *
 * `null` bounds mean "unbounded on that side", which is how `all` clears the
 * filter without needing a separate signal.
 */
export type DatePresetKey =
  | 'all'
  | 'today'
  | 'last_7_days'
  | 'last_30_days'
  | 'this_month'
  | 'last_month'
  | 'custom'

/** Presets in menu order. `custom` is handled by the panel, not by this table. */
export const DATE_PRESET_KEYS: DatePresetKey[] = [
  'all',
  'today',
  'last_7_days',
  'last_30_days',
  'this_month',
  'last_month',
]

export interface DateRange {
  /** Inclusive lower bound as `yyyy-MM-dd`, or null for unbounded. */
  from: string | null
  /** Inclusive upper bound as `yyyy-MM-dd`, or null for unbounded. */
  to: string | null
}

/**
 * Resolve a preset into concrete `yyyy-MM-dd` bounds.
 *
 * The timezone argument is not decoration: these ranges are relative to *now*,
 * and "today" means today where the merchant trades. Computing them in the
 * browser's zone puts the boundary hours off for anyone checking a store from
 * another country — and it moves depending on who is looking, which makes a
 * shared link mean different things to two people.
 *
 * Bounds are whole dates because that is what the filter stores and what
 * Ransack compares against; the day itself is the smallest unit a merchant
 * reasons about here.
 */
export function resolveDatePreset(preset: DatePresetKey, timezone: string): DateRange {
  if (preset === 'all' || preset === 'custom') return { from: null, to: null }

  // "Now" shifted so that reading its *local* fields yields the store's
  // wall-clock date. All arithmetic below then happens on the merchant's
  // calendar, and `format` reads those same local fields back out.
  //
  // `formatInTimeZone` must not be used on these values: it would convert a
  // second time, moving every bound by the offset that was already applied.
  const now = toZonedTime(new Date(), timezone)
  const day = (date: Date) => format(date, 'yyyy-MM-dd')

  switch (preset) {
    case 'today':
      return { from: day(now), to: day(now) }
    case 'last_7_days':
      return { from: day(subDays(now, 6)), to: day(now) }
    case 'last_30_days':
      return { from: day(subDays(now, 29)), to: day(now) }
    case 'this_month':
      return { from: day(startOfMonth(now)), to: day(now) }
    case 'last_month': {
      const previous = subMonths(now, 1)
      return {
        from: day(startOfMonth(previous)),
        // The day before this month starts — avoids month-length arithmetic.
        to: day(subDays(startOfMonth(now), 1)),
      }
    }
  }
}

/**
 * Recognise which preset a pair of bounds came from, so a filter restored from
 * the URL re-selects its menu entry instead of always reading as "Custom".
 *
 * Matching by value rather than storing the preset key keeps the filter a plain
 * `FilterRule` — the preset is a way of writing a range, not a thing the rest
 * of the pipeline has to know about. A range that no longer matches any preset
 * (yesterday's "last 7 days", reopened today) correctly reads as custom.
 */
export function matchDatePreset(range: DateRange, timezone: string): DatePresetKey {
  if (!range.from && !range.to) return 'all'
  for (const key of DATE_PRESET_KEYS) {
    if (key === 'all') continue
    const candidate = resolveDatePreset(key, timezone)
    if (candidate.from === range.from && candidate.to === range.to) return key
  }
  return 'custom'
}

import { matchDateRangePreset, resolveDateRangePreset } from '@spree/dashboard-ui'
import { parse } from 'date-fns'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

// A fixed instant with a deliberately awkward property: 23:30 UTC on the 15th
// is already the 16th in Sydney and still the 15th in Los Angeles. Every
// assertion below turns on which calendar the range is computed against.
const INSTANT = new Date('2026-03-15T23:30:00Z')

beforeEach(() => {
  vi.useFakeTimers()
  vi.setSystemTime(INSTANT)
})

afterEach(() => {
  vi.useRealTimers()
})

describe('resolveDateRangePreset', () => {
  it('counts last-N ranges inclusively, so last 30 days is 30 dates', () => {
    const range = resolveDateRangePreset('30d', 'UTC')
    expect(day(range.from)).toBe('2026-02-14')
    expect(day(range.to)).toBe('2026-03-15')
  })

  it('counts last 90 days as 90 dates, not 91', () => {
    const range = resolveDateRangePreset('90d', 'UTC')
    expect(day(range.from)).toBe('2025-12-16')
    expect(day(range.to)).toBe('2026-03-15')
  })

  it('reads "this month" and year-to-date on the store calendar', () => {
    expect(day(resolveDateRangePreset('this_month', 'UTC').from)).toBe('2026-03-01')
    expect(day(resolveDateRangePreset('ytd', 'UTC').from)).toBe('2026-01-01')
    expect(day(resolveDateRangePreset('this_month', 'Australia/Sydney').from)).toBe('2026-03-01')
    expect(day(resolveDateRangePreset('this_month', 'Australia/Sydney').to)).toBe('2026-03-16')
  })
})

describe('matchDateRangePreset', () => {
  it('recognises a range it produced, so a remounted picker re-selects its entry', () => {
    const range = resolveDateRangePreset('90d', 'UTC')
    expect(matchDateRangePreset(range, 'UTC')).toBe('90d')
  })

  it('recognises a range written as bare dates, the way the dashboard seeds last 30 days', () => {
    const from = parse('2026-02-14', 'yyyy-MM-dd', new Date())
    const to = parse('2026-03-15', 'yyyy-MM-dd', new Date())
    expect(matchDateRangePreset({ from, to }, 'UTC')).toBe('30d')
  })

  it('reads a hand-picked range as custom', () => {
    const from = parse('2026-01-02', 'yyyy-MM-dd', new Date())
    const to = parse('2026-01-09', 'yyyy-MM-dd', new Date())
    expect(matchDateRangePreset({ from, to }, 'UTC')).toBe('custom')
  })

  it('reads a stale preset as custom once it no longer matches', () => {
    const from = parse('2026-03-08', 'yyyy-MM-dd', new Date())
    const to = parse('2026-03-14', 'yyyy-MM-dd', new Date())
    expect(matchDateRangePreset({ from, to }, 'UTC')).toBe('custom')
  })
})

function day(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

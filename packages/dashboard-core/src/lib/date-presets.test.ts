import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { matchDatePreset, resolveDatePreset } from './date-presets'

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

describe('resolveDatePreset', () => {
  it('reads "today" on the store\'s calendar, not the viewer\'s', () => {
    // Same instant, three zones, three different answers for "today". This is
    // the whole reason the timezone is threaded through.
    expect(resolveDatePreset('today', 'America/Los_Angeles')).toEqual({
      from: '2026-03-15',
      to: '2026-03-15',
    })
    expect(resolveDatePreset('today', 'UTC')).toEqual({ from: '2026-03-15', to: '2026-03-15' })
    expect(resolveDatePreset('today', 'Australia/Sydney')).toEqual({
      from: '2026-03-16',
      to: '2026-03-16',
    })
  })

  it('counts "last 7 days" inclusively, so it spans exactly 7 dates', () => {
    expect(resolveDatePreset('last_7_days', 'UTC')).toEqual({
      from: '2026-03-09',
      to: '2026-03-15',
    })
  })

  it('runs "this month" from the 1st to today', () => {
    expect(resolveDatePreset('this_month', 'UTC')).toEqual({
      from: '2026-03-01',
      to: '2026-03-15',
    })
  })

  it('ends "last month" the day before this one starts, whatever its length', () => {
    // February 2026 has 28 days — derived, never assumed.
    expect(resolveDatePreset('last_month', 'UTC')).toEqual({
      from: '2026-02-01',
      to: '2026-02-28',
    })
  })

  it('treats "all" as unbounded on both sides', () => {
    expect(resolveDatePreset('all', 'UTC')).toEqual({ from: null, to: null })
  })
})

describe('matchDatePreset', () => {
  it('recognises a range it produced, so a restored filter re-selects its entry', () => {
    const range = resolveDatePreset('last_30_days', 'UTC')
    expect(matchDatePreset(range, 'UTC')).toBe('last_30_days')
  })

  it('reads empty bounds as "all"', () => {
    expect(matchDatePreset({ from: null, to: null }, 'UTC')).toBe('all')
  })

  it('reads a hand-picked range as custom', () => {
    expect(matchDatePreset({ from: '2026-01-02', to: '2026-01-09' }, 'UTC')).toBe('custom')
  })

  it('reads a stale preset as custom once it no longer matches', () => {
    // Yesterday's "last 7 days", reopened today, is a fixed range that no
    // preset would produce now — calling it "Last 7 days" would misdescribe
    // what the list is actually filtered to.
    const stale = { from: '2026-03-08', to: '2026-03-14' }
    expect(matchDatePreset(stale, 'UTC')).toBe('custom')
  })

  it('does not match a range computed in another zone', () => {
    const sydney = resolveDatePreset('today', 'Australia/Sydney')
    expect(matchDatePreset(sydney, 'America/Los_Angeles')).toBe('custom')
  })
})

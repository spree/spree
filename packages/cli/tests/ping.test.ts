import { describe, expect, it } from 'vitest'
import { formatPingStatus, isPingFailure, type PingResult } from '../src/api/ping'

// biome-ignore lint/suspicious/noControlCharactersInRegex: matching ANSI SGR escapes
const stripAnsi = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '')

describe('isPingFailure', () => {
  it('treats a rejected key and an unreachable host as failures', () => {
    expect(isPingFailure({ status: 'unauthorized' })).toBe(true)
    expect(isPingFailure({ status: 'unreachable', message: 'ECONNREFUSED' })).toBe(true)
  })

  it('does NOT treat connected or forbidden as failures', () => {
    // `forbidden` = valid key that just lacks read_settings — still a healthy credential.
    expect(isPingFailure({ status: 'connected', storeName: 'Shop' })).toBe(false)
    expect(isPingFailure({ status: 'forbidden' })).toBe(false)
  })
})

describe('formatPingStatus', () => {
  const cases: Array<[PingResult, string]> = [
    [{ status: 'connected', storeName: 'Shop' }, 'connected (Shop)'],
    [{ status: 'forbidden' }, 'connected (key valid; lacks read_settings for store details)'],
    [{ status: 'unauthorized' }, 'key rejected (401)'],
    [{ status: 'unreachable', message: 'ECONNREFUSED' }, 'unreachable — ECONNREFUSED'],
  ]

  it.each(cases)('renders %j', (ping, expected) => {
    expect(stripAnsi(formatPingStatus(ping))).toBe(expected)
  })
})

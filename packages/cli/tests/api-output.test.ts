import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { colorizeJson, printResult } from '../src/api/output'

// biome-ignore lint/suspicious/noControlCharactersInRegex: matching ANSI SGR escapes
const ANSI = /\x1b\[[0-9;]*m/g
const stripAnsi = (s: string) => s.replace(ANSI, '')

describe('printResult JSON output', () => {
  let stdout: string
  let spy: ReturnType<typeof vi.spyOn>
  const originalIsTTY = process.stdout.isTTY

  beforeEach(() => {
    stdout = ''
    spy = vi.spyOn(process.stdout, 'write').mockImplementation((chunk) => {
      stdout += String(chunk)
      return true
    })
  })

  afterEach(() => {
    spy.mockRestore()
    Object.defineProperty(process.stdout, 'isTTY', { value: originalIsTTY, configurable: true })
  })

  function setTTY(value: boolean) {
    Object.defineProperty(process.stdout, 'isTTY', { value, configurable: true })
  }

  it('emits compact, uncolored JSON when piped (non-TTY)', () => {
    setTTY(false)
    printResult({ name: 'Tee', price: 10 })
    // Compact (no indentation) and no ANSI escapes that would break `jq`.
    expect(stdout).toBe('{"name":"Tee","price":10}\n')
    expect(stdout).not.toMatch(ANSI)
  })

  it('emits indented, colored JSON in a terminal (TTY)', () => {
    setTTY(true)
    printResult({ name: 'Tee' })
    expect(stripAnsi(stdout)).toBe('{\n  "name": "Tee"\n}\n')
  })

  it('round-trips back to the same value regardless of destination', () => {
    const value = { data: [{ id: 'prod_1', qty: 3, active: true, tag: null }], meta: { count: 1 } }

    setTTY(false)
    printResult(value)
    expect(JSON.parse(stdout)).toEqual(value)

    stdout = ''
    setTTY(true)
    printResult(value)
    expect(JSON.parse(stripAnsi(stdout))).toEqual(value)
  })

  it('prints nothing for null/undefined', () => {
    setTTY(true)
    printResult(null)
    printResult(undefined)
    expect(stdout).toBe('')
  })
})

describe('colorizeJson', () => {
  it('does not mistake a colon inside a string value for a key', () => {
    const colored = colorizeJson(JSON.stringify({ note: 'a: b' }, null, 2))
    expect(JSON.parse(stripAnsi(colored))).toEqual({ note: 'a: b' })
  })

  it('leaves structure untouched after stripping color', () => {
    const input = JSON.stringify({ n: 1, arr: [true, null] }, null, 2)
    expect(stripAnsi(colorizeJson(input))).toBe(input)
  })
})

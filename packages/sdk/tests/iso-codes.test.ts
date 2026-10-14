import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import {
  CountryCode,
  CurrencyCode,
  isCountryCode,
  isCurrencyCode,
  isLocaleCode,
  LocaleCode,
} from '../src'

// The values a closed schema of the API reference lists, read from its
// `components.schemas` block without parsing the whole file.
function referenceCodes(api: string, schema: string): string[] {
  const lines = readFileSync(
    resolve(__dirname, `../../../docs/api-reference/${api}.yaml`),
    'utf-8',
  ).split('\n')
  const start = lines.indexOf(`    ${schema}:`)
  if (start === -1) return []

  const codes: string[] = []
  for (const line of lines.slice(start + 1)) {
    if (/^ {4}\S/.test(line)) break
    const match = line.match(/^ {6}- '?([^']+?)'?$/)
    if (match) codes.push(match[1])
  }
  return codes.sort()
}

describe('ISO code lists', () => {
  it.each([
    ['store', 'CountryCode', CountryCode],
    ['store', 'CurrencyCode', CurrencyCode],
    ['store', 'LocaleCode', LocaleCode],
    ['admin', 'CountryCode', CountryCode],
    ['admin', 'CurrencyCode', CurrencyCode],
    ['admin', 'LocaleCode', LocaleCode],
    ['seller', 'CountryCode', CountryCode],
    ['seller', 'CurrencyCode', CurrencyCode],
  ])('match the %s API reference %s list', (api, schema, list) => {
    const expected = referenceCodes(api, schema)

    expect(expected.length).toBeGreaterThan(0)
    expect(Object.values(list).sort(), 'Run `pnpm generate:iso-codes`').toEqual(expected)
  })

  it('name each code by its standard value', () => {
    expect(CountryCode.US).toBe('US')
    expect(CurrencyCode.EUR).toBe('EUR')
    expect(LocaleCode.pt_BR).toBe('pt-BR')
  })

  it('recognise only listed codes', () => {
    expect(isCountryCode('DE')).toBe(true)
    expect(isCountryCode('ZZ')).toBe(false)
    expect(isCountryCode('de')).toBe(false)
    expect(isCurrencyCode('JPY')).toBe(true)
    expect(isCurrencyCode('XYZ')).toBe(false)
    expect(isLocaleCode('es-419')).toBe(true)
    expect(isLocaleCode('es_419')).toBe(false)
    expect(isLocaleCode(null)).toBe(false)
  })
})

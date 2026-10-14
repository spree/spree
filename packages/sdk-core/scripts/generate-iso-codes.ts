import * as fs from 'node:fs'
import * as path from 'node:path'
import { parse } from 'yaml'

// Writes the country, currency and locale code lists every SDK exports, from
// the closed `CountryCode` / `CurrencyCode` / `LocaleCode` schemas in the Store
// API reference — the server's own lists. Each code is documented with its
// English name, so editors show "US Dollar" when hovering `USD`:
//
//   pnpm generate:iso-codes
//
// A name comes from the runtime's `Intl.DisplayNames` only the first time its
// code appears; after that it is read back from the generated file. Names
// differ between Node versions, so this keeps the output the same on every
// machine and lets CI check it.

type Spec = { components: { schemas: Record<string, { enum?: string[] }> } }

const root = path.resolve(import.meta.dirname, '../../..')
const spec = parse(
  fs.readFileSync(path.join(root, 'docs/api-reference/store.yaml'), 'utf8'),
) as Spec
const outputPath = path.resolve(import.meta.dirname, '../src/iso-codes.generated.ts')

// Names already written, keyed by code (the three lists never share a code).
const existingNames = new Map<string, string>()
if (fs.existsSync(outputPath)) {
  const previous = fs.readFileSync(outputPath, 'utf8')
  for (const [, name, code] of previous.matchAll(/\/\*\* (.+) \*\/\n {2}\S+: '([^']+)',/g)) {
    existingNames.set(code, name)
  }
}

const LISTS = [
  {
    name: 'CountryCode',
    summary: 'ISO 3166-1 alpha-2 country codes, as Spree accepts them.',
    displayNames: new Intl.DisplayNames('en', { type: 'region' }),
  },
  {
    name: 'CurrencyCode',
    summary: 'ISO 4217 currency codes, as Spree accepts them.',
    displayNames: new Intl.DisplayNames('en', { type: 'currency' }),
  },
  {
    name: 'LocaleCode',
    summary:
      'Locale codes (an ISO 639-1 language, optionally with a region) a store may sell and translate content in.',
    displayNames: new Intl.DisplayNames('en', { type: 'language' }),
  },
] as const

// A locale's region needs a property name an identifier can use: `pt-BR` → `pt_BR`.
const keyFor = (code: string) =>
  /^[A-Za-z_][A-Za-z0-9_]*$/.test(code) ? code : code.replace(/-/g, '_')

const sections = LISTS.map(({ name, summary, displayNames }) => {
  const codes = spec.components.schemas[name]?.enum
  if (!codes?.length) throw new Error(`docs/api-reference/store.yaml has no ${name} schema`)

  const entries = [...codes]
    .sort()
    .map(
      (code) =>
        `  /** ${existingNames.get(code) ?? displayNames.of(code) ?? code} */\n  ${keyFor(code)}: '${code}',`,
    )
    .join('\n')

  return `/** ${summary} */
export const ${name} = {
${entries}
} as const

export type ${name} = (typeof ${name})[keyof typeof ${name}]`
})

const source = `// This file is auto-generated from docs/api-reference/store.yaml by \`pnpm generate:iso-codes\`. Do not edit directly.

${sections.join('\n\n')}
`

fs.writeFileSync(outputPath, source)
console.log(`Wrote ${path.relative(root, outputPath)}`)

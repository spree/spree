import * as fs from 'node:fs'
import * as path from 'node:path'
import { parse } from 'yaml'

// Writes the closed code lists every SDK exports — countries, currencies,
// locales and measurement units — from the named schemas in the API
// references, the server's own lists. Each code is documented with its English
// name, so editors show "US Dollar" when hovering `USD`:
//
//   pnpm generate:code-lists
//
// A country, currency or locale name comes from the runtime's
// `Intl.DisplayNames` only the first time its code appears; after that it is
// read back from the generated file. Names differ between Node versions, so
// this keeps the output the same on every machine and lets CI check it.

type Spec = { components?: { schemas?: Record<string, { enum?: string[] }> } }

const root = path.resolve(import.meta.dirname, '../../..')
// Units are only written through the Admin and Seller APIs, so their lists
// are published there rather than in the Store API reference.
const specs = ['store', 'admin'].map(
  (api) =>
    parse(fs.readFileSync(path.join(root, `docs/api-reference/${api}.yaml`), 'utf8')) as Spec,
)
const outputPath = path.resolve(import.meta.dirname, '../src/code-lists.generated.ts')

// Names already written, keyed by list and code: a unit and a locale may
// share a code (`kg`).
const existingNames = new Map<string, string>()
if (fs.existsSync(outputPath)) {
  const previous = fs.readFileSync(outputPath, 'utf8')
  for (const [, list, body] of previous.matchAll(
    /export const (\w+) = \{\n([\s\S]*?)\n\} as const/g,
  )) {
    for (const [, name, code] of body.matchAll(/\/\*\* (.+) \*\/\n {2}\S+: '([^']+)',/g)) {
      existingNames.set(`${list}:${code}`, name)
    }
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
  {
    name: 'WeightUnit',
    summary: 'Units a weight is measured in.',
    names: { g: 'Gram', kg: 'Kilogram', lb: 'Pound', oz: 'Ounce' },
  },
  {
    name: 'DimensionUnit',
    summary: 'Units a length, width, height or depth is measured in.',
    names: { mm: 'Millimeter', cm: 'Centimeter', in: 'Inch', ft: 'Foot' },
  },
] as const satisfies ReadonlyArray<{
  name: string
  summary: string
  displayNames?: Intl.DisplayNames
  names?: Record<string, string>
}>

// `Intl.DisplayNames#of` throws on a code it considers malformed; the bare code
// is the fallback name then.
const displayName = (displayNames: Intl.DisplayNames, code: string) => {
  try {
    return displayNames.of(code) ?? code
  } catch {
    return code
  }
}

// A locale's region needs a property name an identifier can use: `pt-BR` → `pt_BR`.
const keyFor = (code: string) =>
  /^[A-Za-z_][A-Za-z0-9_]*$/.test(code) ? code : code.replace(/-/g, '_')

const sections = LISTS.map((list) => {
  const { name, summary } = list
  const codes = specs.map((spec) => spec.components?.schemas?.[name]?.enum).find(Boolean)
  if (!codes?.length) throw new Error(`No API reference in docs/api-reference has a ${name} schema`)

  // Units keep the server's order, smallest first, which is how a picker lists
  // them; the long ISO lists are sorted.
  const ordered = 'names' in list ? codes : [...codes].sort()
  const nameOf = (code: string) =>
    'names' in list
      ? ((list.names as Record<string, string>)[code] ?? code)
      : (existingNames.get(`${name}:${code}`) ?? displayName(list.displayNames, code))

  const entries = ordered
    .map((code) => `  /** ${nameOf(code)} */\n  ${keyFor(code)}: '${code}',`)
    .join('\n')

  return `/** ${summary} */
export const ${name} = {
${entries}
} as const

export type ${name} = (typeof ${name})[keyof typeof ${name}]`
})

const source = `// This file is auto-generated from docs/api-reference by \`pnpm generate:code-lists\`. Do not edit directly.

${sections.join('\n\n')}
`

fs.writeFileSync(outputPath, source)
console.log(`Wrote ${path.relative(root, outputPath)}`)

import * as fs from 'node:fs'
import * as path from 'node:path'
import { parse } from 'yaml'

// Runs from the SDK package being generated (its `generate:filters` script),
// reading that SDK's API reference and writing its list filter types:
//
//   tsx ../sdk-core/scripts/generate-filters.ts admin
//
// The tables come from the Ransack allowlists, through the swaggerize run
// (`components.x-spree-filter-tables` and each list operation's
// `x-spree-filters`), so the types say exactly what the API accepts.

type Kind =
  | 'text'
  | 'decimal'
  | 'integer'
  | 'date'
  | 'datetime'
  | 'enum'
  | 'id'
  | 'type'
  | 'boolean'
type AttributeKind = Kind | { enum: string[] }
type ScopeType = Kind | Kind[] | { list: Kind }

interface FilterTable {
  attributes: Record<string, AttributeKind>
  associations: Record<string, string>
  scopes: Record<string, ScopeType>
}

interface EndpointFilters {
  table: string
  sortable: string[]
  custom_fields?: boolean
}

interface Spec {
  paths: Record<string, Record<string, { 'x-spree-filters'?: EndpointFilters }>>
  components?: { 'x-spree-filter-tables'?: Record<string, FilterTable> }
}

const MAX_DEPTH = 2
const HEADER =
  '// This file is auto-generated from the filter tables in docs/api-reference by `pnpm generate:filters`. Do not edit directly.\n'

const VALUE_TYPES: Record<Kind, string> = {
  text: 'string',
  decimal: 'string | number',
  integer: 'number',
  date: 'string',
  datetime: 'string',
  enum: 'string',
  id: 'string',
  type: 'string',
  boolean: 'boolean',
}

const literal = (value: string) => `'${value.replace(/'/g, "\\'")}'`
const union = (values: string[]) => values.map(literal).join(' | ')

function fieldsType(table: FilterTable): string {
  const byKind = new Map<string, string[]>()
  const enums: string[] = []

  for (const [attribute, kind] of Object.entries(table.attributes)) {
    if (typeof kind === 'object') {
      enums.push(`Filter.EnumFilters<${literal(attribute)}, ${union(kind.enum)}>`)
      continue
    }
    byKind.set(kind, [...(byKind.get(kind) ?? []), attribute])
  }

  const parts: string[] = []
  const group = (kinds: Kind[]) => kinds.flatMap((kind) => byKind.get(kind) ?? [])
  const add = (attributes: string[], build: (names: string) => string) => {
    if (attributes.length) parts.push(build(union(attributes)))
  }

  add(group(['text']), (names) => `Filter.TextFilters<${names}>`)
  add(group(['decimal']), (names) => `Filter.RangeFilters<${names}, string | number>`)
  add(group(['date', 'datetime']), (names) => `Filter.RangeFilters<${names}>`)
  add(group(['integer']), (names) => `Filter.RangeFilters<${names}, number>`)
  add(group(['id', 'type', 'enum']), (names) => `Filter.IdFilters<${names}>`)
  add(group(['boolean']), (names) => `Filter.BooleanFilters<${names}>`)
  parts.push(...enums)

  return parts.length ? parts.join('\n  & ') : 'Record<never, never>'
}

function scopeValueType(type: ScopeType): string {
  if (Array.isArray(type)) return `[${type.map((kind) => VALUE_TYPES[kind]).join(', ')}]`
  if (typeof type === 'object') return `${VALUE_TYPES[type.list]} | ${VALUE_TYPES[type.list]}[]`
  return VALUE_TYPES[type]
}

function scopesType(table: FilterTable): string | null {
  const entries = Object.entries(table.scopes)
  if (!entries.length) return null

  return `{\n${entries.map(([scope, type]) => `    ${scope}?: ${scopeValueType(type)}`).join('\n')}\n  }`
}

function associationsType(
  tables: Record<string, FilterTable>,
  table: FilterTable,
  depth: number,
): string[] {
  if (depth >= MAX_DEPTH) return []

  return Object.entries(table.associations).map(([association, target]) => {
    const nested = associationsType(tables, tables[target], depth + 1)
    const inner = [`${target}Fields`, ...nested].join(' & ')
    return `Filter.Prefixed<'${association}_', ${inner}>`
  })
}

function render(spec: Spec): string {
  const tables = spec.components?.['x-spree-filter-tables'] ?? {}
  const roots = new Map<string, EndpointFilters>()

  // Endpoints listing the same records share one type; their sort fields and
  // custom-field support combine.
  for (const operations of Object.values(spec.paths)) {
    const filters = operations.get?.['x-spree-filters']
    if (!filters) continue

    const known = roots.get(filters.table)
    roots.set(filters.table, {
      table: filters.table,
      sortable: [...new Set([...(known?.sortable ?? []), ...filters.sortable])].sort(),
      custom_fields: Boolean(known?.custom_fields || filters.custom_fields),
    })
  }

  const out: string[] = []

  for (const name of Object.keys(tables).sort()) {
    out.push(`export type ${name}Fields = ${fieldsType(tables[name])}`, '')
  }

  for (const name of [...roots.keys()].sort()) {
    const endpoint = roots.get(name) as EndpointFilters
    const table = tables[name]
    const parts = [`${name}Fields`, ...associationsType(tables, table, 0), 'Filter.OrFilters']
    const scopes = scopesType(table)
    if (scopes) parts.push(scopes)
    if (endpoint.custom_fields) parts.push('Filter.CustomFieldFilters')

    const sortable = endpoint.sortable.length ? union(endpoint.sortable) : 'never'
    const sort = endpoint.custom_fields
      ? `Filter.SortKey<${sortable} | \`cf_\${string}\`>`
      : `Filter.SortKey<${sortable}>`

    out.push(`export type ${name}Filters = ${parts.join('\n  & ')}`, '')
    out.push(`export type ${name}Sort = ${sort}`, '')
  }

  // A namespace import, so no table name can collide with a building block.
  return `${HEADER}\nimport type * as Filter from '@spree/sdk-core'\n\n${out.join('\n').trimEnd()}\n`
}

const api = process.argv[2]
if (!api) throw new Error('Usage: generate-filters.ts <store|admin|seller>')

const specPath = path.resolve(process.cwd(), `../../docs/api-reference/${api}.yaml`)
const outputPath = path.resolve(process.cwd(), 'src/types/filters.generated.ts')
const spec = parse(fs.readFileSync(specPath, 'utf8')) as Spec

fs.writeFileSync(outputPath, render(spec))
console.log(`Wrote ${path.relative(process.cwd(), outputPath)}`)

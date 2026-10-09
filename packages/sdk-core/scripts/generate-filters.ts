import * as fs from 'node:fs'
import * as path from 'node:path'
import { parse } from 'yaml'
import { FILTER_PREDICATES } from '../src/filters'

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
  components?: {
    'x-spree-filter-tables'?: Record<string, FilterTable>
    'x-spree-filter-predicates'?: Record<Kind, string[]>
  }
}

const PREDICATE_GROUPS: Record<Kind, keyof typeof FILTER_PREDICATES> = {
  text: 'text',
  decimal: 'range',
  integer: 'range',
  date: 'range',
  datetime: 'range',
  enum: 'equality',
  id: 'equality',
  type: 'equality',
  boolean: 'boolean',
}

// The building blocks in sdk-core hard-code the predicates per kind; a spec
// publishing a different set means one side changed without the other.
function checkPredicates(published: Record<Kind, string[]> | undefined) {
  if (!published) throw new Error('The API reference publishes no x-spree-filter-predicates')

  for (const [kind, predicates] of Object.entries(published) as [Kind, string[]][]) {
    const group = FILTER_PREDICATES[PREDICATE_GROUPS[kind]]
    const known = [...group.value, ...group.list, ...group.flag].sort()
    if (known.join(' ') !== [...predicates].sort().join(' ')) {
      throw new Error(
        `Predicates for ${kind} differ: the API publishes ${predicates.join(', ')}, sdk-core has ${known.join(', ')}`,
      )
    }
  }
}

const MAX_DEPTH = 2
const HEADER =
  '// This file is auto-generated from the filter tables in docs/api-reference by `pnpm generate:filters`. Do not edit directly.\n'

// Each kind's TypeScript value and the sdk-core building block typing its
// predicates. Enum attributes carry their values and use `EnumFilters`.
const KIND_TYPES: Record<Exclude<Kind, 'enum'>, { value: string; block: string }> = {
  text: { value: 'string', block: 'TextFilters<$names>' },
  decimal: { value: 'string', block: 'RangeFilters<$names>' },
  integer: { value: 'number', block: 'RangeFilters<$names, number>' },
  date: { value: 'string', block: 'RangeFilters<$names>' },
  datetime: { value: 'string', block: 'RangeFilters<$names>' },
  id: { value: 'string', block: 'IdFilters<$names>' },
  type: { value: 'string', block: 'IdFilters<$names>' },
  boolean: { value: 'boolean', block: 'BooleanFilters<$names>' },
}

const valueType = (kind: Kind) => (kind === 'enum' ? 'string' : KIND_TYPES[kind].value)

const literal = (value: string) => `'${value.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`
const union = (values: string[]) => values.map(literal).join(' | ')

function fieldsType(table: FilterTable): string {
  const byBlock = new Map<string, string[]>()
  const enums: string[] = []

  for (const [attribute, kind] of Object.entries(table.attributes)) {
    if (typeof kind === 'object') {
      enums.push(`Filter.EnumFilters<${literal(attribute)}, ${union(kind.enum)}>`)
      continue
    }
    const block = KIND_TYPES[kind as Exclude<Kind, 'enum'>].block
    byBlock.set(block, [...(byBlock.get(block) ?? []), attribute])
  }

  const parts = [...byBlock].map(
    ([block, names]) => `Filter.${block.replace('$names', union(names))}`,
  )
  parts.push(...enums)

  return parts.length ? parts.join('\n  & ') : 'Record<never, never>'
}

function scopeValueType(type: ScopeType): string {
  if (Array.isArray(type)) return `[${type.map(valueType).join(', ')}]`
  if (typeof type === 'object') return `${valueType(type.list)} | ${valueType(type.list)}[]`
  return valueType(type)
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
  checkPredicates(spec.components?.['x-spree-filter-predicates'])
  const tables = spec.components?.['x-spree-filter-tables'] ?? {}
  // Endpoints listing the same records share one type, keyed by what they
  // accept: the search-backed lists (custom fields, provider sorts) get their
  // own `<Table>Search…` types when plain lists of the same records exist too.
  const groups = new Map<string, { table: string; search: boolean; sortable: Set<string> }>()
  for (const operations of Object.values(spec.paths)) {
    const filters = operations.get?.['x-spree-filters']
    if (!filters) continue

    const search = Boolean(filters.custom_fields)
    const key = `${filters.table}:${search}`
    const group = groups.get(key) ?? { table: filters.table, search, sortable: new Set<string>() }
    for (const field of filters.sortable) group.sortable.add(field)
    groups.set(key, group)
  }

  const out: string[] = []

  for (const name of Object.keys(tables).sort()) {
    out.push(`export type ${name}Fields = ${fieldsType(tables[name])}`, '')
  }

  const sorted = [...groups.values()].sort(
    (a, b) => a.table.localeCompare(b.table) || Number(a.search) - Number(b.search),
  )
  for (const { table: name, search, sortable } of sorted) {
    const table = tables[name]
    const typeName = search && groups.has(`${name}:false`) ? `${name}Search` : name
    const parts = [`${name}Fields`, ...associationsType(tables, table, 0), 'Filter.OrFilters']
    const scopes = scopesType(table)
    if (scopes) parts.push(scopes)
    if (search) parts.push('Filter.CustomFieldFilters')

    const fields = sortable.size ? union([...sortable].sort()) : 'never'
    const sort = search
      ? `Filter.SortKey<${fields} | \`cf_\${string}\`>`
      : `Filter.SortKey<${fields}>`

    // Filters an app adds through its own extensions, which the published
    // types cannot know about: `declare module` the SDK and add them here.
    if (typeName === name) out.push(`export interface ${name}FilterExtensions {}`, '')
    parts.push(`${name}FilterExtensions`)
    out.push(`export type ${typeName}Filters = ${parts.join('\n  & ')}`, '')
    out.push(`export type ${typeName}Sort = ${sort}`, '')
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

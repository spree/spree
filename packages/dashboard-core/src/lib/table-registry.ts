import type { ReactNode } from 'react'

// ============================================================================
// Types
// ============================================================================

/** Shared shape — every column has these regardless of filter type. */
interface ColumnDefBase<T = any> {
  key: string
  label: string
  sortable?: boolean
  filterable?: boolean
  default?: boolean
  /** Ransack attribute name if different from key (e.g., 'master_sku' for 'sku') */
  ransackAttribute?: string
  /** Custom cell renderer. If omitted, renders `row[key]` as text. */
  render?: (row: T) => ReactNode
  /** Cell className */
  className?: string
  /** Whether this column is displayable in the table. Set to false for filter-only columns. */
  displayable?: boolean
}

/**
 * Config for `filterType: 'resource'` — drives a `<ResourceMultiAutocomplete>`
 * inside the filter panel and hydrates labels in the active-filter chip.
 *
 * `search` is called as the user types. `hydrate` resolves currently-selected
 * IDs (deep-link reload, navigating back to the page) to records so the chip
 * can show human-readable names instead of raw prefixed IDs.
 */
export interface ResourceFilterConfig<R extends { id: string } = { id: string }> {
  queryKey: string
  search: (query: string) => Promise<{ data: R[] }>
  hydrate: (ids: string[]) => Promise<{ data: R[] }>
  getOptionLabel: (option: R) => string
  placeholder?: string
  emptyText?: string
}

/**
 * Models that `TagCombobox` can target for tag autocomplete. The three
 * first-class taggables (Product, User, Order) get autocomplete hints, but
 * the union is open — apps can pass any Ruby class string the backend's
 * `TagsController#allowed_taggable_types` accepts (override that method
 * server-side to extend). Use `Subject.Product` etc. to avoid stringly-typed
 * callsites for the built-ins.
 */
export type TaggableType = 'Spree::Product' | 'Spree::User' | 'Spree::Order' | (string & {})

/**
 * Column definition. Discriminated union on `filterType`:
 *   - `'enum'`     → `filterOptions` is **required**
 *   - `'resource'` → `filterResource` is **required** (multi-select picker)
 *   - `'tags'`     → `taggableType` is **required** (drives TagCombobox)
 *   - other types  → all variant fields must be omitted
 */
export type ColumnDef<T = any> =
  | (ColumnDefBase<T> & {
      filterType?: 'string' | 'boolean' | 'number' | 'date' | 'currency'
      filterOptions?: never
      filterResource?: never
      taggableType?: never
    })
  | (ColumnDefBase<T> & {
      filterType: 'enum'
      filterOptions: { value: string; label: string }[]
      filterResource?: never
      taggableType?: never
    })
  | (ColumnDefBase<T> & {
      filterType: 'resource'
      filterOptions?: never
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      filterResource: ResourceFilterConfig<any>
      taggableType?: never
    })
  | (ColumnDefBase<T> & {
      filterType: 'tags'
      filterOptions?: never
      filterResource?: never
      taggableType: TaggableType
    })

export interface FilterRule {
  id: string
  field: string
  operator: string
  /**
   * For array-valued operators (`in`, `not_in`) and the `'resource'` filter
   * type, the IDs are encoded as a trimmed CSV string. Use `parseFilterIds`
   * to decode and `ids.join(',')` to encode — keeps URL serialization simple.
   */
  value: string
}

export function parseFilterIds(value: string): string[] {
  return value
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
}

export interface SortOption {
  field: string
  direction: 'asc' | 'desc'
}

export interface TableDef<T = any> {
  key: string
  title?: string
  columns: ColumnDef<T>[]
  searchParam?: string
  searchPlaceholder?: string
  defaultSort?: SortOption
  emptyIcon?: ReactNode
  emptyMessage?: string
}

// ============================================================================
// Registry
// ============================================================================

const registry = new Map<string, TableDef>()

/**
 * Queued mutations against tables that haven't been `defineTable`-d yet.
 *
 * Built-in tables register via side-effect imports in route files
 * (`import '@/tables/products'`) — they only execute when the route loads.
 * Plugin authors who call `tables.products.addColumn(...)` from their
 * boot-time entry module would race with that lazy registration. To avoid
 * forcing every plugin to know which routes have loaded, mutations on an
 * unregistered table are queued and replayed by `defineTable` when the
 * table appears.
 *
 * Mutations on tables that NEVER register stay in the queue and never fire,
 * which is the right semantics: a plugin extending an optional feature
 * shouldn't crash when that feature isn't installed.
 */
const pending = new Map<string, Array<(t: TableDef) => void>>()

function enqueue(tableKey: string, fn: (t: TableDef) => void) {
  const list = pending.get(tableKey) ?? []
  list.push(fn)
  pending.set(tableKey, list)
}

function flushPending(tableKey: string, table: TableDef) {
  const queue = pending.get(tableKey)
  if (!queue) return
  pending.delete(tableKey)
  // Iterate the full queue even if individual mutations throw. A plugin that
  // registers a duplicate column shouldn't silently drop every later mutation
  // for the same table — collect errors and surface them all.
  const errors: unknown[] = []
  for (const fn of queue) {
    try {
      fn(table)
    } catch (err) {
      errors.push(err)
    }
  }
  if (errors.length === 1) throw errors[0]
  if (errors.length > 1) {
    throw new AggregateError(errors, `${errors.length} mutation(s) failed for table "${tableKey}"`)
  }
}

export function defineTable<T = any>(key: string, def: Omit<TableDef<T>, 'key'>): TableDef<T> {
  const tableDef = { ...def, key } as TableDef<T>
  registry.set(key, tableDef)
  flushPending(key, tableDef as TableDef)
  return tableDef
}

export function getTable<T = any>(key: string): TableDef<T> {
  const table = registry.get(key)
  if (!table)
    throw new Error(`Table "${key}" is not registered. Call defineTable("${key}", ...) first.`)
  return table as TableDef<T>
}

// ============================================================================
// Mutation API — allows extensions to modify registered tables
// ============================================================================

export const tables = new Proxy({} as Record<string, TableMutator>, {
  get(_target, key: string) {
    return createMutator(key)
  },
})

interface TableMutator {
  addColumn<T = any>(column: ColumnDef<T>): void
  removeColumn(key: string): void
  updateColumn<T = any>(key: string, updates: Partial<ColumnDef<T>>): void
}

function applyAddColumn(table: TableDef, column: ColumnDef) {
  if (table.columns.some((c) => c.key === column.key)) {
    throw new Error(
      `Column "${column.key}" already exists in table "${table.key}". Use updateColumn() instead.`,
    )
  }
  table.columns.push(column)
}

function applyRemoveColumn(table: TableDef, key: string) {
  table.columns = table.columns.filter((c) => c.key !== key)
}

function applyUpdateColumn(table: TableDef, key: string, updates: Partial<ColumnDef>) {
  const col = table.columns.find((c) => c.key === key)
  if (!col) throw new Error(`Column "${key}" not found in table "${table.key}".`)
  Object.assign(col, updates)
}

function createMutator(tableKey: string): TableMutator {
  return {
    addColumn(column) {
      const table = registry.get(tableKey)
      if (table) applyAddColumn(table, column as ColumnDef)
      else enqueue(tableKey, (t) => applyAddColumn(t, column as ColumnDef))
    },
    removeColumn(key) {
      const table = registry.get(tableKey)
      if (table) applyRemoveColumn(table, key)
      else enqueue(tableKey, (t) => applyRemoveColumn(t, key))
    },
    updateColumn(key, updates) {
      const table = registry.get(tableKey)
      if (table) applyUpdateColumn(table, key, updates as Partial<ColumnDef>)
      else enqueue(tableKey, (t) => applyUpdateColumn(t, key, updates as Partial<ColumnDef>))
    },
  }
}

/** Test-only: clear the registry and any pending mutations. */
export function __resetTableRegistry(): void {
  registry.clear()
  pending.clear()
}

// ============================================================================
// Helpers
// ============================================================================

/** Get columns that are displayable (not filter-only) */
export function getDisplayableColumns<T = any>(table: TableDef<T>): ColumnDef<T>[] {
  return table.columns.filter((c) => c.displayable !== false)
}

/** Get default visible column keys */
export function getDefaultColumnKeys(table: TableDef): string[] {
  return getDisplayableColumns(table)
    .filter((c) => c.default)
    .map((c) => c.key)
}

/** Get columns that can be filtered */
export function getFilterableColumns(table: TableDef): ColumnDef[] {
  return table.columns.filter((c) => c.filterable)
}

/** Get columns that can be sorted */
export function getSortableColumns(table: TableDef): ColumnDef[] {
  return table.columns.filter((c) => c.sortable)
}

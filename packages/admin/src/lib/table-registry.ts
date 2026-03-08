import type { ReactNode } from 'react'

// ============================================================================
// Types
// ============================================================================

export interface ColumnDef<T = any> {
  key: string
  label: string
  sortable?: boolean
  filterable?: boolean
  default?: boolean
  filterType?: 'string' | 'status' | 'boolean' | 'number' | 'date'
  filterOptions?: { value: string; label: string }[]
  /** Ransack attribute name if different from key (e.g., 'master_sku' for 'sku') */
  ransackAttribute?: string
  /** Custom cell renderer. If omitted, renders `row[key]` as text. */
  render?: (row: T) => ReactNode
  /** Cell className */
  className?: string
  /** Whether this column is displayable in the table. Set to false for filter-only columns. */
  displayable?: boolean
}

export interface FilterRule {
  id: string
  field: string
  operator: string
  value: string
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

export function defineTable<T = any>(key: string, def: Omit<TableDef<T>, 'key'>): TableDef<T> {
  const tableDef = { ...def, key } as TableDef<T>
  registry.set(key, tableDef)
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

function createMutator(tableKey: string): TableMutator {
  return {
    addColumn(column) {
      const table = registry.get(tableKey)
      if (!table) throw new Error(`Table "${tableKey}" is not registered.`)
      // Prevent duplicates
      if (table.columns.some((c) => c.key === column.key)) {
        throw new Error(
          `Column "${column.key}" already exists in table "${tableKey}". Use updateColumn() instead.`,
        )
      }
      table.columns.push(column)
    },
    removeColumn(key) {
      const table = registry.get(tableKey)
      if (!table) throw new Error(`Table "${tableKey}" is not registered.`)
      table.columns = table.columns.filter((c) => c.key !== key)
    },
    updateColumn(key, updates) {
      const table = registry.get(tableKey)
      if (!table) throw new Error(`Table "${tableKey}" is not registered.`)
      const col = table.columns.find((c) => c.key === key)
      if (!col) throw new Error(`Column "${key}" not found in table "${tableKey}".`)
      Object.assign(col, updates)
    },
  }
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

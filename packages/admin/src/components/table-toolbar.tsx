import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuCheckboxItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
} from '@/components/ui/dropdown-menu'
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
  SheetFooter,
  SheetClose,
} from '@/components/ui/sheet'
import {
  SearchIcon,
  XIcon,
  FilterIcon,
  ArrowUpDownIcon,
  Columns3Icon,
  PlusIcon,
  Trash2Icon,
} from 'lucide-react'
import { useState, useCallback, useRef, useEffect } from 'react'

// ============================================================================
// Types
// ============================================================================

export interface ColumnDef {
  key: string
  label: string
  sortable?: boolean
  filterable?: boolean
  default?: boolean
  filterType?: 'string' | 'status' | 'boolean' | 'number' | 'date'
  filterOptions?: { value: string; label: string }[]
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

interface TableToolbarProps {
  columns: ColumnDef[]
  visibleColumns: string[]
  onVisibleColumnsChange: (columns: string[]) => void
  search: string
  onSearchChange: (value: string) => void
  searchPlaceholder?: string
  sort: SortOption
  onSortChange: (sort: SortOption) => void
  filters: FilterRule[]
  onFiltersChange: (filters: FilterRule[]) => void
  actions?: React.ReactNode
}

// ============================================================================
// Operators
// ============================================================================

const operatorsByType: Record<string, { value: string; label: string }[]> = {
  string: [
    { value: 'cont', label: 'contains' },
    { value: 'eq', label: 'equals' },
    { value: 'not_eq', label: 'does not equal' },
    { value: 'start', label: 'starts with' },
    { value: 'end', label: 'ends with' },
    { value: 'present', label: 'is set' },
    { value: 'blank', label: 'is not set' },
  ],
  status: [
    { value: 'eq', label: 'is' },
    { value: 'not_eq', label: 'is not' },
    { value: 'in', label: 'is any of' },
    { value: 'not_in', label: 'is none of' },
  ],
  boolean: [
    { value: 'eq', label: 'is' },
  ],
  number: [
    { value: 'eq', label: 'equals' },
    { value: 'gt', label: 'greater than' },
    { value: 'gteq', label: 'greater than or equal' },
    { value: 'lt', label: 'less than' },
    { value: 'lteq', label: 'less than or equal' },
  ],
  date: [
    { value: 'eq', label: 'is' },
    { value: 'gt', label: 'after' },
    { value: 'lt', label: 'before' },
    { value: 'gteq', label: 'on or after' },
    { value: 'lteq', label: 'on or before' },
  ],
}

function getOperators(type: string) {
  return operatorsByType[type] || operatorsByType.string
}

const noValueOperators = ['present', 'blank']

// ============================================================================
// TableToolbar
// ============================================================================

export function TableToolbar({
  columns,
  visibleColumns,
  onVisibleColumnsChange,
  search,
  onSearchChange,
  searchPlaceholder = 'Search...',
  sort,
  onSortChange,
  filters,
  onFiltersChange,
  actions,
}: TableToolbarProps) {
  const [filterOpen, setFilterOpen] = useState(false)
  const searchRef = useRef<HTMLInputElement>(null)

  const sortableColumns = columns.filter((c) => c.sortable)
  const filterableColumns = columns.filter((c) => c.filterable)
  const activeFilterCount = filters.length

  return (
    <>
      <div className="flex flex-col lg:flex-row gap-3 items-start lg:items-center justify-between p-3 border-b border-gray-200">
        <div className="flex gap-2 items-center flex-wrap">
          {/* Search */}
          <div className="relative lg:w-[300px]">
            <SearchIcon className="absolute left-2.5 top-1/2 -translate-y-1/2 size-4 text-gray-600 pointer-events-none" />
            <Input
              ref={searchRef}
              placeholder={searchPlaceholder}
              value={search}
              onChange={(e) => onSearchChange(e.target.value)}
              className="pl-8 pr-8 h-[2.125rem]"
            />
            {search && (
              <button
                type="button"
                className="absolute right-2 top-1/2 -translate-y-1/2 p-0.5 text-gray-400 hover:text-gray-600"
                onClick={() => {
                  onSearchChange('')
                  searchRef.current?.focus()
                }}
              >
                <XIcon className="size-3.5" />
              </button>
            )}
          </div>
        </div>

        <div className="flex gap-2 items-center">
          {/* Filter button */}
          {filterableColumns.length > 0 && (
            <Button
              variant="outline"
              size="sm"
              className="h-[2.125rem]"
              onClick={() => setFilterOpen(true)}
            >
              <FilterIcon className="size-4" />
              Filters
              {activeFilterCount > 0 && (
                <Badge className="ml-1 px-1.5 py-0 text-xs">{activeFilterCount}</Badge>
              )}
            </Button>
          )}

          {/* Sort dropdown */}
          {sortableColumns.length > 0 && (
            <SortDropdown
              columns={sortableColumns}
              sort={sort}
              onSortChange={onSortChange}
            />
          )}

          {/* Column selector */}
          <ColumnSelector
            columns={columns.filter((c) => c.default !== undefined)}
            visibleColumns={visibleColumns}
            onVisibleColumnsChange={onVisibleColumnsChange}
          />

          {actions}
        </div>
      </div>

      {/* Active filter badges */}
      {filters.length > 0 && (
        <div className="flex gap-2 flex-wrap px-3 py-2 border-b border-gray-200">
          {filters.map((filter) => {
            const col = columns.find((c) => c.key === filter.field)
            const ops = getOperators(col?.filterType ?? 'string')
            const opLabel = ops.find((o) => o.value === filter.operator)?.label ?? filter.operator
            return (
              <Badge key={filter.id} className="gap-1.5 pr-1">
                <span className="font-medium">{col?.label ?? filter.field}</span>
                <span className="text-muted-foreground">{opLabel}</span>
                {!noValueOperators.includes(filter.operator) && (
                  <span className="font-medium">{filter.value}</span>
                )}
                <button
                  type="button"
                  className="ml-0.5 p-0.5 rounded-sm hover:bg-gray-200"
                  onClick={() => onFiltersChange(filters.filter((f) => f.id !== filter.id))}
                >
                  <XIcon className="size-3" />
                </button>
              </Badge>
            )
          })}
          <button
            type="button"
            className="text-xs text-muted-foreground hover:text-foreground"
            onClick={() => onFiltersChange([])}
          >
            Clear all
          </button>
        </div>
      )}

      {/* Filter drawer */}
      <FilterDrawer
        open={filterOpen}
        onOpenChange={setFilterOpen}
        columns={filterableColumns}
        filters={filters}
        onApply={onFiltersChange}
      />
    </>
  )
}

// ============================================================================
// Sort Dropdown
// ============================================================================

function SortDropdown({
  columns,
  sort,
  onSortChange,
}: {
  columns: ColumnDef[]
  sort: SortOption
  onSortChange: (sort: SortOption) => void
}) {
  const currentCol = columns.find((c) => c.key === sort.field)
  const currentLabel = currentCol?.label ?? 'Sort'
  const dirLabel = sort.direction === 'asc' ? 'A-Z' : 'Z-A'

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="h-[2.125rem]">
          <ArrowUpDownIcon className="size-4" />
          {currentCol ? `${currentLabel} (${dirLabel})` : 'Sort'}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="min-w-48">
        <DropdownMenuLabel>Sort by</DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuRadioGroup
          value={`${sort.field}:${sort.direction}`}
          onValueChange={(val) => {
            const [field, direction] = val.split(':')
            onSortChange({ field, direction: direction as 'asc' | 'desc' })
          }}
        >
          {columns.map((col) => (
            <div key={col.key}>
              <DropdownMenuRadioItem value={`${col.key}:asc`}>
                {col.label} (A-Z)
              </DropdownMenuRadioItem>
              <DropdownMenuRadioItem value={`${col.key}:desc`}>
                {col.label} (Z-A)
              </DropdownMenuRadioItem>
            </div>
          ))}
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

// ============================================================================
// Column Selector
// ============================================================================

function ColumnSelector({
  columns,
  visibleColumns,
  onVisibleColumnsChange,
}: {
  columns: ColumnDef[]
  visibleColumns: string[]
  onVisibleColumnsChange: (columns: string[]) => void
}) {
  const defaults = columns.filter((c) => c.default).map((c) => c.key)

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="h-[2.125rem]">
          <Columns3Icon className="size-4" />
          Columns
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="min-w-48">
        <DropdownMenuLabel>Visible columns</DropdownMenuLabel>
        <DropdownMenuSeparator />
        {columns.map((col) => (
          <DropdownMenuCheckboxItem
            key={col.key}
            checked={visibleColumns.includes(col.key)}
            onCheckedChange={(checked) => {
              onVisibleColumnsChange(
                checked
                  ? [...visibleColumns, col.key]
                  : visibleColumns.filter((k) => k !== col.key),
              )
            }}
            onSelect={(e) => e.preventDefault()}
          >
            {col.label}
          </DropdownMenuCheckboxItem>
        ))}
        <DropdownMenuSeparator />
        <div className="px-1 py-1">
          <Button
            variant="ghost"
            size="sm"
            className="w-full justify-center"
            onClick={() => onVisibleColumnsChange(defaults)}
          >
            Reset to default
          </Button>
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

// ============================================================================
// Filter Drawer
// ============================================================================

function FilterDrawer({
  open,
  onOpenChange,
  columns,
  filters: initialFilters,
  onApply,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  columns: ColumnDef[]
  filters: FilterRule[]
  onApply: (filters: FilterRule[]) => void
}) {
  const [draft, setDraft] = useState<FilterRule[]>(initialFilters)

  // Sync draft when opened
  useEffect(() => {
    if (open) setDraft(initialFilters)
  }, [open, initialFilters])

  const addFilter = useCallback(() => {
    const first = columns[0]
    if (!first) return
    setDraft((prev) => [
      ...prev,
      {
        id: crypto.randomUUID(),
        field: first.key,
        operator: getOperators(first.filterType ?? 'string')[0].value,
        value: '',
      },
    ])
  }, [columns])

  const updateFilter = useCallback((id: string, update: Partial<FilterRule>) => {
    setDraft((prev) =>
      prev.map((f) => (f.id === id ? { ...f, ...update } : f)),
    )
  }, [])

  const removeFilter = useCallback((id: string) => {
    setDraft((prev) => prev.filter((f) => f.id !== id))
  }, [])

  function handleApply() {
    // Remove filters with no value (unless operator doesn't need one)
    const valid = draft.filter(
      (f) => noValueOperators.includes(f.operator) || f.value.trim() !== '',
    )
    onApply(valid)
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" showCloseButton={false}>
        <SheetHeader>
          <SheetTitle>Filters</SheetTitle>
          <SheetDescription className="sr-only">Build filters for the table</SheetDescription>
          <SheetClose asChild>
            <Button variant="ghost" size="icon-sm">
              <XIcon />
            </Button>
          </SheetClose>
        </SheetHeader>

        <div className="flex-1 overflow-y-auto p-4 space-y-3">
          {draft.map((filter) => {
            const col = columns.find((c) => c.key === filter.field)
            const type = col?.filterType ?? 'string'
            const ops = getOperators(type)

            return (
              <div
                key={filter.id}
                className="flex items-center gap-2 p-3 bg-gray-50 rounded-lg"
              >
                {/* Field select */}
                <select
                  className="flex-1 rounded-lg border border-border bg-white py-1.5 px-2 text-sm outline-none focus:outline-2 focus:outline-offset-2 focus:outline-blue-500"
                  value={filter.field}
                  onChange={(e) => {
                    const newCol = columns.find((c) => c.key === e.target.value)
                    const newOps = getOperators(newCol?.filterType ?? 'string')
                    updateFilter(filter.id, {
                      field: e.target.value,
                      operator: newOps[0].value,
                      value: '',
                    })
                  }}
                >
                  {columns.map((c) => (
                    <option key={c.key} value={c.key}>
                      {c.label}
                    </option>
                  ))}
                </select>

                {/* Operator select */}
                <select
                  className="w-[140px] shrink-0 rounded-lg border border-border bg-white py-1.5 px-2 text-sm outline-none focus:outline-2 focus:outline-offset-2 focus:outline-blue-500"
                  value={filter.operator}
                  onChange={(e) => updateFilter(filter.id, { operator: e.target.value })}
                >
                  {ops.map((op) => (
                    <option key={op.value} value={op.value}>
                      {op.label}
                    </option>
                  ))}
                </select>

                {/* Value input */}
                {!noValueOperators.includes(filter.operator) && (
                  col?.filterType === 'status' && col.filterOptions ? (
                    <select
                      className="flex-1 rounded-lg border border-border bg-white py-1.5 px-2 text-sm outline-none focus:outline-2 focus:outline-offset-2 focus:outline-blue-500"
                      value={filter.value}
                      onChange={(e) => updateFilter(filter.id, { value: e.target.value })}
                    >
                      <option value="">Select...</option>
                      {col.filterOptions.map((opt) => (
                        <option key={opt.value} value={opt.value}>
                          {opt.label}
                        </option>
                      ))}
                    </select>
                  ) : col?.filterType === 'boolean' ? (
                    <select
                      className="flex-1 rounded-lg border border-border bg-white py-1.5 px-2 text-sm outline-none focus:outline-2 focus:outline-offset-2 focus:outline-blue-500"
                      value={filter.value}
                      onChange={(e) => updateFilter(filter.id, { value: e.target.value })}
                    >
                      <option value="">Select...</option>
                      <option value="true">Yes</option>
                      <option value="false">No</option>
                    </select>
                  ) : (
                    <input
                      type={col?.filterType === 'number' ? 'number' : col?.filterType === 'date' ? 'date' : 'text'}
                      className="flex-1 rounded-lg border border-border bg-white py-1.5 px-2 text-sm outline-none focus:outline-2 focus:outline-offset-2 focus:outline-blue-500"
                      placeholder="Enter value..."
                      value={filter.value}
                      onChange={(e) => updateFilter(filter.id, { value: e.target.value })}
                    />
                  )
                )}

                {/* Remove button */}
                <button
                  type="button"
                  className="p-1.5 rounded-lg text-red-600 hover:bg-red-50 shrink-0"
                  onClick={() => removeFilter(filter.id)}
                >
                  <Trash2Icon className="size-4" />
                </button>
              </div>
            )
          })}

          {draft.length === 0 && (
            <p className="text-sm text-muted-foreground text-center py-6">
              No filters applied. Click "Add filter" to get started.
            </p>
          )}

          <Button
            variant="outline"
            size="sm"
            onClick={addFilter}
          >
            <PlusIcon className="size-4" />
            Add filter
          </Button>
        </div>

        <SheetFooter>
          <SheetClose asChild>
            <Button variant="outline">Discard</Button>
          </SheetClose>
          <div className="flex gap-2">
            <Button
              variant="outline"
              onClick={() => setDraft([])}
            >
              Clear all
            </Button>
            <Button onClick={handleApply}>
              Apply filters
            </Button>
          </div>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

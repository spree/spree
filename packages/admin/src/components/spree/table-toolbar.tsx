import {
  ArrowUpDownIcon,
  Columns3Icon,
  FilterIcon,
  PlusIcon,
  SearchIcon,
  Trash2Icon,
  XIcon,
} from 'lucide-react'
import { useCallback, useRef, useState } from 'react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { CardTitle } from '@/components/ui/card'
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Input } from '@/components/ui/input'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'
import type { ColumnDef, FilterRule, SortOption } from '@/lib/table-registry'

interface TableToolbarProps {
  /** Displayable columns (for column selector and table headers) */
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
  /** All columns including filter-only ones (for the filter drawer). Falls back to `columns` if not provided. */
  allColumns?: ColumnDef[]
  /** Title displayed in the toolbar header */
  title?: string
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
  boolean: [{ value: 'eq', label: 'is' }],
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
  allColumns,
  title,
  actions,
}: TableToolbarProps) {
  const [filterOpen, setFilterOpen] = useState(false)
  const searchRef = useRef<HTMLInputElement>(null)

  const allCols = allColumns ?? columns
  const sortableColumns = allCols.filter((c) => c.sortable)
  const filterableColumns = allCols.filter((c) => c.filterable)
  const activeFilterCount = filters.length

  return (
    <>
      <div className="flex flex-col lg:flex-row gap-3 items-start lg:items-center justify-between p-3 border-b border-border">
        {title && <CardTitle>{title}</CardTitle>}
        <div className="flex gap-2 items-center flex-wrap ml-auto">
          {/* Search */}
          <div className="flex items-center gap-2 border border-border bg-card rounded-lg shadow-xs px-2.5 h-[2.125rem] lg:w-[300px] focus-within:border-blue-500 focus-within:shadow-[0_0_0_3px_rgba(59,130,246,0.15)] transition-all duration-100 ease-in-out">
            <SearchIcon className="size-4 text-muted-foreground shrink-0" />
            <input
              ref={searchRef}
              placeholder={searchPlaceholder}
              value={search}
              onChange={(e) => onSearchChange(e.target.value)}
              className="h-full w-full border-0 bg-transparent p-0 text-sm text-foreground placeholder:text-muted-foreground outline-none focus:ring-0"
            />
            {search && (
              <button
                type="button"
                className="p-0.5 text-muted-foreground hover:text-foreground shrink-0"
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
            <Popover open={filterOpen} onOpenChange={setFilterOpen}>
              <Tooltip>
                <TooltipTrigger asChild>
                  <PopoverTrigger asChild>
                    <Button variant="outline" size="sm" className="h-[2.125rem]">
                      <FilterIcon className="size-4" />
                      {activeFilterCount > 0 && (
                        <Badge className="ml-1 px-1.5 py-0 text-xs">{activeFilterCount}</Badge>
                      )}
                    </Button>
                  </PopoverTrigger>
                </TooltipTrigger>
                <TooltipContent>Filters</TooltipContent>
              </Tooltip>
              <PopoverContent align="end" className="w-[480px] p-0">
                <FilterPanel
                  columns={filterableColumns}
                  filters={filters}
                  onApply={(f) => {
                    onFiltersChange(f)
                    setFilterOpen(false)
                  }}
                  onClose={() => setFilterOpen(false)}
                />
              </PopoverContent>
            </Popover>
          )}

          {/* Sort dropdown */}
          {sortableColumns.length > 0 && (
            <SortDropdown columns={sortableColumns} sort={sort} onSortChange={onSortChange} />
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
        <div className="flex gap-2 flex-wrap px-3 py-2 border-b border-border">
          {filters.map((filter) => {
            const col = allCols.find((c) => c.key === filter.field)
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
                  className="ml-0.5 p-0.5 rounded-sm hover:bg-accent"
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

  return (
    <DropdownMenu>
      <Tooltip>
        <TooltipTrigger asChild>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" size="sm" className="h-[2.125rem]">
              <ArrowUpDownIcon className="size-4" />
            </Button>
          </DropdownMenuTrigger>
        </TooltipTrigger>
        <TooltipContent>{currentCol?.label ?? 'Sort'}</TooltipContent>
      </Tooltip>
      <DropdownMenuContent align="end" className="min-w-48">
        <DropdownMenuLabel>Sort by</DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuRadioGroup
          value={sort.field}
          onValueChange={(field) => onSortChange({ field, direction: sort.direction })}
        >
          {columns.map((col) => (
            <DropdownMenuRadioItem key={col.key} value={col.key}>
              {col.label}
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
        <DropdownMenuSeparator />
        <DropdownMenuLabel>Order</DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuRadioGroup
          value={sort.direction}
          onValueChange={(dir) =>
            onSortChange({
              field: sort.field,
              direction: dir as 'asc' | 'desc',
            })
          }
        >
          <DropdownMenuRadioItem value="asc">Ascending</DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="desc">Descending</DropdownMenuRadioItem>
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
      <Tooltip>
        <TooltipTrigger asChild>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" size="sm" className="h-[2.125rem]">
              <Columns3Icon className="size-4" />
            </Button>
          </DropdownMenuTrigger>
        </TooltipTrigger>
        <TooltipContent>Columns</TooltipContent>
      </Tooltip>
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

function FilterPanel({
  columns,
  filters: initialFilters,
  onApply,
  onClose,
}: {
  columns: ColumnDef[]
  filters: FilterRule[]
  onApply: (filters: FilterRule[]) => void
  onClose: () => void
}) {
  const [draft, setDraft] = useState<FilterRule[]>(initialFilters)

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
    setDraft((prev) => prev.map((f) => (f.id === id ? { ...f, ...update } : f)))
  }, [])

  const removeFilter = useCallback((id: string) => {
    setDraft((prev) => prev.filter((f) => f.id !== id))
  }, [])

  function handleApply() {
    const valid = draft.filter(
      (f) => noValueOperators.includes(f.operator) || f.value.trim() !== '',
    )
    onApply(valid)
  }

  return (
    <div className="flex flex-col">
      <div className="flex items-center justify-between border-b px-3 py-2">
        <span className="text-sm font-medium">Filters</span>
        <button type="button" onClick={onClose} className="p-1 rounded hover:bg-muted">
          <XIcon className="size-3.5" />
        </button>
      </div>

      <div className="max-h-[320px] overflow-y-auto p-3 space-y-2">
        {draft.map((filter) => {
          const col = columns.find((c) => c.key === filter.field)
          const type = col?.filterType ?? 'string'
          const ops = getOperators(type)

          return (
            <div key={filter.id} className="flex items-center gap-1.5">
              <Select
                value={filter.field}
                onValueChange={(val) => {
                  const newCol = columns.find((c) => c.key === val)
                  const newOps = getOperators(newCol?.filterType ?? 'string')
                  updateFilter(filter.id, {
                    field: val,
                    operator: newOps[0].value,
                    value: '',
                  })
                }}
              >
                <SelectTrigger size="sm" className="flex-1">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {columns.map((c) => (
                    <SelectItem key={c.key} value={c.key}>
                      {c.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              <Select
                value={filter.operator}
                onValueChange={(val) => updateFilter(filter.id, { operator: val })}
              >
                <SelectTrigger size="sm" className="w-[120px] shrink-0">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {ops.map((op) => (
                    <SelectItem key={op.value} value={op.value}>
                      {op.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              {!noValueOperators.includes(filter.operator) &&
                (col?.filterType === 'status' && col.filterOptions ? (
                  <Select
                    value={filter.value || undefined}
                    onValueChange={(val) => updateFilter(filter.id, { value: val })}
                  >
                    <SelectTrigger size="sm" className="flex-1">
                      <SelectValue placeholder="Select..." />
                    </SelectTrigger>
                    <SelectContent>
                      {col.filterOptions.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                ) : col?.filterType === 'boolean' ? (
                  <Select
                    value={filter.value || undefined}
                    onValueChange={(val) => updateFilter(filter.id, { value: val })}
                  >
                    <SelectTrigger size="sm" className="flex-1">
                      <SelectValue placeholder="Select..." />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="true">Yes</SelectItem>
                      <SelectItem value="false">No</SelectItem>
                    </SelectContent>
                  </Select>
                ) : (
                  <Input
                    type={
                      col?.filterType === 'number'
                        ? 'number'
                        : col?.filterType === 'date'
                          ? 'date'
                          : 'text'
                    }
                    className="flex-1 py-1 px-2 text-sm h-7"
                    placeholder="Value..."
                    value={filter.value}
                    onChange={(e) => updateFilter(filter.id, { value: e.target.value })}
                  />
                ))}

              <button
                type="button"
                className="p-1 rounded text-muted-foreground hover:text-destructive hover:bg-destructive/10 shrink-0"
                onClick={() => removeFilter(filter.id)}
              >
                <Trash2Icon className="size-3.5" />
              </button>
            </div>
          )
        })}

        {draft.length === 0 && (
          <p className="text-xs text-muted-foreground text-center py-4">
            No filters. Click below to add one.
          </p>
        )}
      </div>

      <div className="flex items-center justify-between border-t px-3 py-2">
        <Button variant="ghost" size="sm" onClick={addFilter}>
          <PlusIcon className="size-3.5" />
          Add filter
        </Button>
        <div className="flex gap-1.5">
          {draft.length > 0 && (
            <Button variant="ghost" size="sm" onClick={() => setDraft([])}>
              Clear
            </Button>
          )}
          <Button size="sm" onClick={handleApply}>
            Apply
          </Button>
        </div>
      </div>
    </div>
  )
}

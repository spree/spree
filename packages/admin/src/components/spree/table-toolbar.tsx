import { useQuery } from '@tanstack/react-query'
import {
  ArrowUpDownIcon,
  Columns3Icon,
  FilterIcon,
  PlusIcon,
  SearchIcon,
  Trash2Icon,
  XIcon,
} from 'lucide-react'
import { useCallback, useMemo, useRef, useState } from 'react'
import { ResourceMultiAutocomplete } from '@/components/spree/resource-multi-autocomplete'
import { StoreDatePicker } from '@/components/spree/store-date-picker'
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
import { useTranslation } from '@/lib/i18n'
import {
  type ColumnDef,
  type FilterRule,
  parseFilterIds,
  type SortOption,
} from '@/lib/table-registry'
import { useStore } from '@/providers/store-provider'

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
  /** Hide the sort dropdown — used when the table is drag-reorderable, where free sorting would defeat the drag. */
  hideSort?: boolean
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
  enum: [
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
  resource: [
    { value: 'in', label: 'is any of' },
    { value: 'not_in', label: 'is none of' },
  ],
  // Same shape as `enum` — the value picker just sources its option list
  // from the active store's `supported_currencies`.
  currency: [
    { value: 'eq', label: 'is' },
    { value: 'not_eq', label: 'is not' },
    { value: 'in', label: 'is any of' },
    { value: 'not_in', label: 'is none of' },
  ],
}

function getOperators(type: string) {
  return operatorsByType[type] || operatorsByType.string
}

const noValueOperators = ['present', 'blank']

const booleanItems = [
  { value: 'true', label: 'Yes' },
  { value: 'false', label: 'No' },
] as const

// ============================================================================
// TableToolbar
// ============================================================================

export function TableToolbar({
  columns,
  visibleColumns,
  onVisibleColumnsChange,
  search,
  onSearchChange,
  searchPlaceholder,
  sort,
  onSortChange,
  filters,
  onFiltersChange,
  allColumns,
  title,
  actions,
  hideSort = false,
}: TableToolbarProps) {
  const { t } = useTranslation()
  const [filterOpen, setFilterOpen] = useState(false)
  const searchRef = useRef<HTMLInputElement>(null)

  const allCols = allColumns ?? columns
  // Memoize so `FilterPanel`'s `useMemo` deps stay stable across parent
  // re-renders. Otherwise picking a filter value triggers an `items` change
  // in the field-picker Select, which Base UI re-emits as a state change.
  const sortableColumns = useMemo(() => allCols.filter((c) => c.sortable), [allCols])
  const filterableColumns = useMemo(() => allCols.filter((c) => c.filterable), [allCols])
  const activeFilterCount = filters.length

  return (
    <>
      <div className="flex flex-col lg:flex-row gap-2 items-start lg:items-center justify-between p-3 border-b border-border">
        {title && <CardTitle>{title}</CardTitle>}
        <div className="flex gap-2 items-center flex-wrap ml-auto">
          {/* Search */}
          <div className="flex items-center gap-2 border border-border bg-card rounded-lg shadow-xs px-2.5 h-[2.125rem] lg:w-[300px] focus-within:border-blue-500 focus-within:shadow-[0_0_0_3px_rgba(59,130,246,0.15)] transition-all duration-100 ease-in-out">
            <SearchIcon className="size-4 text-muted-foreground shrink-0" />
            <input
              ref={searchRef}
              placeholder={
                searchPlaceholder ?? t('admin.components.table_toolbar.search_placeholder')
              }
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
                        <Badge variant="outline" className="ml-1 px-1.5 py-0 text-xs">
                          {activeFilterCount}
                        </Badge>
                      )}
                    </Button>
                  </PopoverTrigger>
                </TooltipTrigger>
                <TooltipContent>
                  {t('admin.components.table_toolbar.filters_button')}
                </TooltipContent>
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

          {/* Sort dropdown — hidden when the table is drag-reorderable, since free sorting would defeat the drag. */}
          {!hideSort && sortableColumns.length > 0 && (
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
          {filters.map((filter) => (
            <FilterChip
              key={filter.id}
              filter={filter}
              col={allCols.find((c) => c.key === filter.field)}
              onRemove={() => onFiltersChange(filters.filter((f) => f.id !== filter.id))}
            />
          ))}
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
// Filter Chip
// ============================================================================

function FilterChip({
  filter,
  col,
  onRemove,
}: {
  filter: FilterRule
  col: ColumnDef | undefined
  onRemove: () => void
}) {
  const ops = getOperators(col?.filterType ?? 'string')
  const opLabel = ops.find((o) => o.value === filter.operator)?.label ?? filter.operator
  const showValue = !noValueOperators.includes(filter.operator)

  return (
    <Badge variant="outline" className="gap-1.5 pr-0.5">
      <span className="font-medium">{col?.label ?? filter.field}</span>
      <span className="text-muted-foreground">{opLabel}</span>
      {showValue &&
        (col?.filterType === 'resource' && col.filterResource ? (
          <ResourceFilterValue value={filter.value} config={col.filterResource} />
        ) : (
          <span className="font-medium">{filter.value}</span>
        ))}
      <button
        type="button"
        className="ml-0.5 p-0.5 rounded-full hover:bg-accent"
        onClick={onRemove}
      >
        <XIcon className="size-3" />
      </button>
    </Badge>
  )
}

/**
 * Hydrates the CSV id list in a resource filter into human labels. Reuses
 * the resource's `hydrate` callback so each chip benefits from React Query's
 * cache (the picker inside the panel populates the same `queryKey`).
 */
function ResourceFilterValue({
  value,
  config,
}: {
  value: string
  config: NonNullable<ColumnDef['filterResource']>
}) {
  const ids = useMemo(() => parseFilterIds(value), [value])

  const { data } = useQuery({
    queryKey: ['filter-chip', config.queryKey, ids],
    queryFn: () => config.hydrate(ids),
    enabled: ids.length > 0,
    staleTime: 60_000,
  })

  if (ids.length === 0) return null

  const labels = ids.map((id) => {
    const record = data?.data.find((r) => r.id === id)
    return record ? config.getOptionLabel(record) : id
  })

  return <span className="font-medium">{labels.join(', ')}</span>
}

/**
 * Currency value-picker for `filterType: 'currency'`. Options come from the
 * active store's `supported_currencies`. Branches on operator: `eq`/`not_eq`
 * use a single `<Select>`; `in`/`not_in` accept a CSV via Base UI's
 * multi-select Combobox chips, matching the other array-valued filters.
 */
function CurrencyFilterPicker({
  value,
  operator,
  onChange,
}: {
  value: string
  operator: string
  onChange: (next: string) => void
}) {
  const { t } = useTranslation()
  const { currencies } = useStore()
  const items = useMemo(
    () => currencies.map((code) => ({ value: code, label: code })),
    [currencies],
  )

  if (operator === 'in' || operator === 'not_in') {
    return (
      <div className="flex-1 min-w-0">
        <CurrencyMultiSelect
          codes={currencies}
          value={parseFilterIds(value)}
          onChange={(next) => onChange(next.join(','))}
        />
      </div>
    )
  }

  return (
    <Select items={items} value={value || undefined} onValueChange={(val) => onChange(val)}>
      <SelectTrigger size="sm" className="flex-1">
        <SelectValue placeholder={t('admin.components.table_toolbar.filter_select_placeholder')} />
      </SelectTrigger>
      <SelectContent>
        {items.map((opt) => (
          <SelectItem key={opt.value} value={opt.value}>
            {opt.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function CurrencyMultiSelect({
  codes,
  value,
  onChange,
}: {
  codes: string[]
  value: string[]
  onChange: (next: string[]) => void
}) {
  function toggle(code: string) {
    onChange(value.includes(code) ? value.filter((c) => c !== code) : [...value, code])
  }
  return (
    <div className="flex flex-wrap gap-1 rounded-md border border-input px-2 py-1.5 text-sm">
      {codes.map((code) => {
        const selected = value.includes(code)
        return (
          <button
            key={code}
            type="button"
            onClick={() => toggle(code)}
            className={`rounded px-1.5 py-0.5 text-xs font-medium ${
              selected
                ? 'bg-primary text-primary-foreground'
                : 'bg-muted text-muted-foreground hover:bg-accent'
            }`}
          >
            {code}
          </button>
        )
      })}
    </div>
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
  const { t } = useTranslation()
  const [draft, setDraft] = useState<FilterRule[]>(initialFilters)
  // Stable `{ value, label }` array for the field-picker `<Select items>`.
  // Building it inline per render produces a new reference each time, which
  // Base UI's Select treats as an `items` change and re-emits state — causing
  // a "Maximum update depth exceeded" loop when the value-Select sits inside
  // the same panel.
  const fieldItems = useMemo(
    () => columns.map((c) => ({ value: c.key, label: c.label })),
    [columns],
  )

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
        <span className="text-sm font-medium">
          {t('admin.components.table_toolbar.filters_button')}
        </span>
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
                items={fieldItems}
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
                items={ops}
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
                (col?.filterType === 'resource' && col.filterResource ? (
                  <div className="flex-1 min-w-0">
                    <ResourceMultiAutocomplete
                      queryKey={col.filterResource.queryKey}
                      value={parseFilterIds(filter.value)}
                      onChange={(ids) => updateFilter(filter.id, { value: ids.join(',') })}
                      search={col.filterResource.search}
                      hydrate={col.filterResource.hydrate}
                      getOptionLabel={col.filterResource.getOptionLabel}
                      placeholder={col.filterResource.placeholder}
                      emptyText={col.filterResource.emptyText}
                    />
                  </div>
                ) : col?.filterType === 'enum' && col.filterOptions ? (
                  <Select
                    items={col.filterOptions}
                    value={filter.value || undefined}
                    onValueChange={(val) => updateFilter(filter.id, { value: val })}
                  >
                    <SelectTrigger size="sm" className="flex-1">
                      <SelectValue
                        placeholder={t('admin.components.table_toolbar.filter_select_placeholder')}
                      />
                    </SelectTrigger>
                    <SelectContent>
                      {col.filterOptions.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                ) : col?.filterType === 'currency' ? (
                  <CurrencyFilterPicker
                    value={filter.value}
                    operator={filter.operator}
                    onChange={(val) => updateFilter(filter.id, { value: val })}
                  />
                ) : col?.filterType === 'boolean' ? (
                  <Select
                    items={booleanItems}
                    value={filter.value || undefined}
                    onValueChange={(val) => updateFilter(filter.id, { value: val })}
                  >
                    <SelectTrigger size="sm" className="flex-1">
                      <SelectValue
                        placeholder={t('admin.components.table_toolbar.filter_select_placeholder')}
                      />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="true">Yes</SelectItem>
                      <SelectItem value="false">No</SelectItem>
                    </SelectContent>
                  </Select>
                ) : col?.filterType === 'date' ? (
                  // Filter values are stored as plain strings; for dates we
                  // persist `yyyy-MM-dd`, which Ransack accepts as-is for
                  // `*_eq`/`*_gt`/`*_lt`. The picker emits `yyyy-MM-dd`
                  // directly in date-only mode.
                  <div className="flex-1">
                    <StoreDatePicker
                      value={filter.value || null}
                      onChange={(next) => updateFilter(filter.id, { value: next ?? '' })}
                      placeholder={t('admin.components.table_toolbar.filter_date_placeholder')}
                    />
                  </div>
                ) : (
                  <Input
                    type={col?.filterType === 'number' ? 'number' : 'text'}
                    className="flex-1 py-1 px-2 text-sm h-7"
                    placeholder={t('admin.components.table_toolbar.filter_text_placeholder')}
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

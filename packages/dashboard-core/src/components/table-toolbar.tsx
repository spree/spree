import {
  Badge,
  Button,
  CardTitle,
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Input,
  Popover,
  PopoverContent,
  PopoverTrigger,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@spree/dashboard-ui'
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
import { useTranslation } from 'react-i18next'
import {
  type ColumnDef,
  type FilterRule,
  parseFilterIds,
  type SortOption,
} from '../lib/table-registry'
import { useStore } from '../providers/store-provider'
import { ResourceMultiAutocomplete } from './resource-multi-autocomplete'
import { StoreDatePicker } from './store-date-picker'
import { TagCombobox } from './tag-combobox'

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

// Operator labels are stored as i18n keys (`admin.components.table_toolbar.operators.*`)
// and resolved with `t()` at render time so they follow the active language.
const operatorsByType: Record<string, { value: string; labelKey: string }[]> = {
  string: [
    { value: 'cont', labelKey: 'admin.components.table_toolbar.operators.contains' },
    { value: 'eq', labelKey: 'admin.components.table_toolbar.operators.equals' },
    { value: 'not_eq', labelKey: 'admin.components.table_toolbar.operators.does_not_equal' },
    { value: 'start', labelKey: 'admin.components.table_toolbar.operators.starts_with' },
    { value: 'end', labelKey: 'admin.components.table_toolbar.operators.ends_with' },
    { value: 'present', labelKey: 'admin.components.table_toolbar.operators.is_set' },
    { value: 'blank', labelKey: 'admin.components.table_toolbar.operators.is_not_set' },
  ],
  enum: [
    { value: 'eq', labelKey: 'admin.components.table_toolbar.operators.is' },
    { value: 'not_eq', labelKey: 'admin.components.table_toolbar.operators.is_not' },
    { value: 'in', labelKey: 'admin.components.table_toolbar.operators.is_any_of' },
    { value: 'not_in', labelKey: 'admin.components.table_toolbar.operators.is_none_of' },
  ],
  boolean: [{ value: 'eq', labelKey: 'admin.components.table_toolbar.operators.is' }],
  number: [
    { value: 'eq', labelKey: 'admin.components.table_toolbar.operators.equals' },
    { value: 'gt', labelKey: 'admin.components.table_toolbar.operators.greater_than' },
    { value: 'gteq', labelKey: 'admin.components.table_toolbar.operators.greater_than_or_equal' },
    { value: 'lt', labelKey: 'admin.components.table_toolbar.operators.less_than' },
    { value: 'lteq', labelKey: 'admin.components.table_toolbar.operators.less_than_or_equal' },
  ],
  date: [
    { value: 'eq', labelKey: 'admin.components.table_toolbar.operators.is' },
    { value: 'gt', labelKey: 'admin.components.table_toolbar.operators.after' },
    { value: 'lt', labelKey: 'admin.components.table_toolbar.operators.before' },
    { value: 'gteq', labelKey: 'admin.components.table_toolbar.operators.on_or_after' },
    { value: 'lteq', labelKey: 'admin.components.table_toolbar.operators.on_or_before' },
  ],
  resource: [
    { value: 'in', labelKey: 'admin.components.table_toolbar.operators.is_any_of' },
    { value: 'not_in', labelKey: 'admin.components.table_toolbar.operators.is_none_of' },
  ],
  // Tag names round-trip as CSV; `filtersToRansack` decodes to the
  // `tags_name_in` / `tags_name_not_in` predicate when emitting Ransack.
  tags: [
    { value: 'in', labelKey: 'admin.components.table_toolbar.operators.is_any_of' },
    { value: 'not_in', labelKey: 'admin.components.table_toolbar.operators.is_none_of' },
  ],
  // Same shape as `enum` — the value picker just sources its option list
  // from the active store's `supported_currencies`.
  currency: [
    { value: 'eq', labelKey: 'admin.components.table_toolbar.operators.is' },
    { value: 'not_eq', labelKey: 'admin.components.table_toolbar.operators.is_not' },
    { value: 'in', labelKey: 'admin.components.table_toolbar.operators.is_any_of' },
    { value: 'not_in', labelKey: 'admin.components.table_toolbar.operators.is_none_of' },
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
            {t('admin.components.table_toolbar.clear_all')}
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
  const { t } = useTranslation()
  const ops = getOperators(col?.filterType ?? 'string')
  const opLabelKey = ops.find((o) => o.value === filter.operator)?.labelKey
  const opLabel = opLabelKey ? t(opLabelKey) : filter.operator
  const showValue = !noValueOperators.includes(filter.operator)

  return (
    <Badge variant="outline" className="gap-1.5 pr-0.5">
      <span className="font-medium">{col?.label ?? filter.field}</span>
      <span className="text-muted-foreground">{opLabel}</span>
      {showValue &&
        (col?.filterType === 'resource' && col.filterResource ? (
          <ResourceFilterValue value={filter.value} config={col.filterResource} />
        ) : col?.filterType === 'tags' ? (
          <span className="font-medium">{parseFilterIds(filter.value).join(', ')}</span>
        ) : col?.filterType === 'enum' && col.filterOptions ? (
          <span className="font-medium">
            {col.filterOptions.find((o) => o.value === filter.value)?.label ?? filter.value}
          </span>
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
  const { t } = useTranslation()
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
        <TooltipContent>
          {currentCol?.label ?? t('admin.components.table_toolbar.sort_tooltip')}
        </TooltipContent>
      </Tooltip>
      <DropdownMenuContent align="end" className="min-w-48">
        <DropdownMenuLabel>{t('admin.components.table_toolbar.sort_by')}</DropdownMenuLabel>
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
        <DropdownMenuLabel>{t('admin.components.table_toolbar.order')}</DropdownMenuLabel>
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
          <DropdownMenuRadioItem value="asc">
            {t('admin.components.table_toolbar.ascending')}
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="desc">
            {t('admin.components.table_toolbar.descending')}
          </DropdownMenuRadioItem>
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
  const { t } = useTranslation()
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
        <TooltipContent>{t('admin.components.table_toolbar.columns_tooltip')}</TooltipContent>
      </Tooltip>
      <DropdownMenuContent align="end" className="min-w-48">
        <DropdownMenuLabel>{t('admin.components.table_toolbar.visible_columns')}</DropdownMenuLabel>
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
            {t('admin.components.table_toolbar.reset_to_default')}
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
  const booleanItems = useMemo(
    () => [
      { value: 'true', label: t('admin.common.yes') },
      { value: 'false', label: t('admin.common.no') },
    ],
    [t],
  )
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
          const ops = getOperators(type).map((op) => ({
            value: op.value,
            label: t(op.labelKey),
          }))

          return (
            <div key={filter.id} className="flex min-w-0 items-center gap-1.5">
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
                ) : col?.filterType === 'tags' && col.taggableType ? (
                  <div className="flex-1 min-w-0">
                    <TagCombobox
                      taggableType={col.taggableType}
                      value={parseFilterIds(filter.value)}
                      onChange={(names) => updateFilter(filter.id, { value: names.join(',') })}
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
                      <SelectItem value="true">{t('admin.common.yes')}</SelectItem>
                      <SelectItem value="false">{t('admin.common.no')}</SelectItem>
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
            {t('admin.components.table_toolbar.no_filters')}
          </p>
        )}
      </div>

      <div className="flex items-center justify-between border-t px-3 py-2">
        <Button variant="ghost" size="sm" onClick={addFilter}>
          <PlusIcon className="size-3.5" />
          {t('admin.components.table_toolbar.add_filter')}
        </Button>
        <div className="flex gap-1.5">
          {draft.length > 0 && (
            <Button variant="ghost" size="sm" onClick={() => setDraft([])}>
              {t('admin.actions.clear')}
            </Button>
          )}
          <Button size="sm" onClick={handleApply}>
            {t('admin.actions.apply')}
          </Button>
        </div>
      </div>
    </div>
  )
}

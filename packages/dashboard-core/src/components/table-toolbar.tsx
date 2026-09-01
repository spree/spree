import {
  Button,
  CardTitle,
  Checkbox,
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
  SearchInput,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  StatusDot,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@spree/dashboard-ui'
import {
  ArrowUpDownIcon,
  CheckIcon,
  ChevronDownIcon,
  ChevronRightIcon,
  Columns3Icon,
  ListFilter,
  XIcon,
} from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { useCallback, useDeferredValue, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { getApiClient } from '../api-client'
import { useAuth } from '../hooks/use-auth'
import {
  DATE_PRESET_KEYS,
  type DatePresetKey,
  matchDatePreset,
  resolveDatePreset,
} from '../lib/date-presets'
import {
  type ColumnDef,
  type FilterRule,
  parseFilterIds,
  type SortOption,
  type TaggableType,
} from '../lib/table-registry'
import { useOptionalStore } from '../providers/store-provider'
import { useTenantId } from '../providers/tenant-provider'
import { StoreDatePicker } from './store-date-picker'

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
    // `i_cont` (case-insensitive) rather than `cont` — an admin typing
    // "2 years" expects to match "2 Years".
    { value: 'i_cont', labelKey: 'admin.components.table_toolbar.operators.contains' },
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

// Operators no longer offered in the picker but still resolvable for display,
// so filters saved in older URLs keep a readable chip label.
const legacyOperatorLabelKeys: Record<string, string> = {
  cont: 'admin.components.table_toolbar.operators.contains',
}

function getOperatorLabelKey(type: string, operator: string) {
  return (
    getOperators(type).find((o) => o.value === operator)?.labelKey ??
    legacyOperatorLabelKeys[operator]
  )
}

const noValueOperators = ['present', 'blank']

/** Stable empty list, so a panel with no store doesn't rebuild `items` (and
 *  re-emit Base UI Select state) on every render. */
const noCurrencies: string[] = []

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

  const allCols = allColumns ?? columns
  // Memoize so `FilterPanel`'s `useMemo` deps stay stable across parent
  // re-renders. Otherwise picking a filter value triggers an `items` change
  // in the field-picker Select, which Base UI re-emits as a state change.
  const sortableColumns = useMemo(() => allCols.filter((c) => c.sortable), [allCols])
  const filterableColumns = useMemo(() => allCols.filter((c) => c.filterable), [allCols])
  // Only enum and date columns have a control worth surfacing — the rest need
  // a free-text value, which is what the popover is for.
  const quickFilterColumns = useMemo(
    () =>
      filterableColumns.filter(
        (c) =>
          c.quickFilter &&
          (c.filterType === 'enum' || c.filterType === 'boolean' || c.filterType === 'date'),
      ),
    [filterableColumns],
  )
  // A filter a quick control actually displays needs no chip — the control
  // already states its value, and a second copy would offer two ways to clear
  // one constraint.
  //
  // Matched on operator as well as field, because each control speaks exactly
  // one: the enum control reads `in`, the date control `gteq`/`lteq`. A
  // `status not_eq active` set from the panel lands on a field a control owns
  // but in an operator it cannot show, so it must keep its chip — hiding it
  // would leave the list filtered by something invisible and unremovable.
  // The field list skips anything with a quick control on the row: that field
  // already has a visible control, and listing it here offers a second route
  // to the same thing. It stays reachable through the panel's field-switch
  // select, which is how a `status is not` gets built.
  const panelColumns = useMemo(() => {
    const covered = new Set(quickFilterColumns.map((c) => c.key))
    return filterableColumns.filter((c) => !covered.has(c.key))
  }, [filterableColumns, quickFilterColumns])
  const chipFilters = useMemo(() => {
    const covered = new Set(
      quickFilterColumns.flatMap((c) =>
        c.filterType === 'date' ? [`${c.key}:gteq`, `${c.key}:lteq`] : [`${c.key}:in`],
      ),
    )
    const visible = filters.filter((f) => !covered.has(`${f.field}:${f.operator}`))

    // A bounded date range is stored as two rules but is one idea, so it shows
    // as one chip. Two chips read as two unrelated filters, and removing
    // either leaves a half-range the operator did not ask for — a "between"
    // that silently became an "after".
    const entries: { key: string; rules: FilterRule[] }[] = []
    const rangeIndex = new Map<string, number>()
    for (const rule of visible) {
      const isBound = rule.operator === 'gteq' || rule.operator === 'lteq'
      const column = allCols.find((c) => c.key === rule.field)
      if (isBound && column?.filterType === 'date') {
        const existing = rangeIndex.get(rule.field)
        if (existing !== undefined) {
          entries[existing].rules.push(rule)
          continue
        }
        rangeIndex.set(rule.field, entries.length)
        entries.push({ key: rule.id, rules: [rule] })
        continue
      }
      entries.push({ key: rule.id, rules: [rule] })
    }
    return entries
  }, [filters, quickFilterColumns, allCols])

  return (
    <>
      {/* Title and page actions only. Every control that acts on the list —
          search, filters, sort, columns — lives on the row below, so the two
          rows split by what they are for rather than by how they are built. */}
      <div className="flex flex-row items-center gap-2 border-b border-border-subtle p-3 pl-4 lg:justify-between">
        {title && <CardTitle className="min-w-0 truncate text-lg">{title}</CardTitle>}
        <div className="ml-auto flex shrink-0 items-center gap-2">{actions}</div>
      </div>

      {/* One filter row: the quick controls and any filters set the long way
          sit together, because to the operator they are the same thing — a
          constraint currently on the list. Splitting them into a "controls"
          band and an "applied" band asked the reader to learn which of their
          own filters lives where, and cost a third row of chrome above every
          table to say it. */}
      {/* Renders whenever the row has anything to hold. Sort and columns count:
          without them a table with no filterable columns would lose both
          controls along with the row. */}
      {(filterableColumns.length > 0 ||
        search ||
        (!hideSort && sortableColumns.length > 0) ||
        columns.some((c) => c.default !== undefined)) && (
        <div className="flex items-start gap-2 border-b border-border-subtle px-3 py-2">
          {/* Only the filters wrap. They grow with what the operator has set,
              where sort and columns are a fixed pair — letting the whole row
              wrap dropped those two onto a line of their own the moment the
              filters filled the width. */}
          <div className="flex min-w-0 flex-1 flex-wrap items-center gap-2">
            {/* Search leads: it is the widest net, and the filters beside it
              narrow what it finds. Hidden on a phone, where the TopBar already
              carries a search field — two search boxes stacked in one column is
              the more confusing cost. A term set on desktop still shows as a
              chip there, so it never filters a list invisibly. */}
            <SearchInput
              value={search}
              onValueChange={onSearchChange}
              placeholder={
                searchPlaceholder ?? t('admin.components.table_toolbar.search_placeholder')
              }
              clearLabel={t('admin.common.clear')}
              className="hidden h-[2.125rem] w-[240px] bg-card text-sm lg:flex"
            />

            {/* Reads as a verb rather than an icon: it is the way *in* to
              everything the quick controls beside it don't cover, so it has to
              look like an action and not a toggle. */}
            {/* Hidden when every filterable field already has a quick control:
              the button would open onto an empty list. */}
            {panelColumns.length > 0 && (
              <Popover open={filterOpen} onOpenChange={setFilterOpen}>
                <PopoverTrigger asChild>
                  <Button variant="outline" size="sm" className="h-11 gap-1.5 lg:h-[2.125rem]">
                    <ListFilter className="size-3.5" />
                    {t('admin.components.table_toolbar.add_filter')}
                  </Button>
                </PopoverTrigger>
                {/* `min(480px, …)` rather than a flat 480px: the panel is wider
                  than a phone, so a fixed width runs its right edge and the
                  Apply button off the screen. */}
                <PopoverContent align="start" className="w-[min(480px,calc(100vw-1rem))] p-0">
                  <FilterPanel
                    columns={panelColumns}
                    allColumns={filterableColumns}
                    filters={filters}
                    onApply={(f) => {
                      onFiltersChange(f)
                      setFilterOpen(false)
                    }}
                    onChange={onFiltersChange}
                    onClose={() => setFilterOpen(false)}
                  />
                </PopoverContent>
              </Popover>
            )}

            {quickFilterColumns.map((col) =>
              col.filterType === 'date' ? (
                <QuickDateFilter
                  key={col.key}
                  column={col}
                  filters={filters}
                  onFiltersChange={onFiltersChange}
                />
              ) : (
                <QuickEnumFilter
                  key={col.key}
                  column={col}
                  filters={filters}
                  onFiltersChange={onFiltersChange}
                />
              ),
            )}

            {/* The search term as a chip, mobile only — the field it came from is
              hidden there, so this is the only way to see or clear it. */}
            {search && (
              <span className="inline-flex h-11 shrink-0 items-center gap-1.5 rounded-lg border border-border bg-muted py-1 pr-1 pl-2.5 text-sm lg:hidden">
                <span className="text-muted-foreground">
                  {t('admin.components.table_toolbar.search_placeholder')}
                </span>
                <span className="truncate">{search}</span>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={t('admin.common.clear')}
                  onClick={() => onSearchChange('')}
                >
                  <XIcon className="size-3.5" />
                </Button>
              </span>
            )}
            {chipFilters.map((entry) => (
              <FilterChip
                key={entry.key}
                rules={entry.rules}
                col={allCols.find((c) => c.key === entry.rules[0].field)}
                onRemove={() => {
                  const removing = new Set(entry.rules.map((r) => r.id))
                  onFiltersChange(filters.filter((f) => !removing.has(f.id)))
                }}
              />
            ))}
            {filters.length > 0 && (
              // Stays borderless while everything beside it is outlined: the
              // rest of the row sets constraints, this one undoes them, and
              // giving it the same weight would make "clear" look like a fifth
              // filter. It matches on height so the row still sits on one line.
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-11 text-muted-foreground hover:text-foreground lg:h-[2.125rem]"
                onClick={() => onFiltersChange([])}
              >
                {t('admin.components.table_toolbar.clear_all')}
              </Button>
            )}
          </div>

          {/* Sort and columns close the row from the right. They shape the
              view rather than narrowing it, so they sit apart from the filters
              — and stay on the first line however many filters are set. */}
          <div className="flex shrink-0 items-center gap-2">
            {/* Hidden when the table is drag-reorderable, since free sorting
                would defeat the drag. */}
            {!hideSort && sortableColumns.length > 0 && (
              <SortDropdown columns={sortableColumns} sort={sort} onSortChange={onSortChange} />
            )}

            {/* Hidden on a phone, where too few columns are visible at once for
                choosing between them to mean anything. */}
            <div className="hidden lg:contents">
              <ColumnSelector
                columns={columns.filter((c) => c.default !== undefined)}
                visibleColumns={visibleColumns}
                onVisibleColumnsChange={onVisibleColumnsChange}
              />
            </div>
          </div>
        </div>
      )}
    </>
  )
}

// ============================================================================
// Filter Chip
// ============================================================================

function FilterChip({
  rules,
  col,
  onRemove,
}: {
  /** Usually one rule; a bounded date range is two, shown as one chip. */
  rules: FilterRule[]
  col: ColumnDef | undefined
  onRemove: () => void
}) {
  const { t, i18n } = useTranslation()
  const first = rules[0]

  /**
   * A `yyyy-MM-dd` bound is a calendar date, not an instant, so it is
   * formatted in the viewer's locale without a timezone conversion — shifting
   * it by a zone offset is what would turn "1 August" into "31 July".
   */
  function formatDate(value: string) {
    const [year, month, day] = value.split('-').map(Number)
    if (!year || !month || !day) return value
    return new Date(year, month - 1, day).toLocaleDateString(i18n.language, {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    })
  }

  // Read the range's ends rather than assuming an order: the two rules arrive
  // in whatever order they were applied.
  const from = rules.find((rule) => rule.operator === 'gteq')?.value
  const to = rules.find((rule) => rule.operator === 'lteq')?.value
  const isRange = col?.filterType === 'date' && rules.length > 1 && from && to

  const label = col?.label ?? first.field
  const opLabelKey = getOperatorLabelKey(col?.filterType ?? 'string', first.operator)
  const opLabel = opLabelKey ? t(opLabelKey) : first.operator
  const showValue = !noValueOperators.includes(first.operator)

  return (
    // Deliberately shaped like the quick-filter buttons beside it rather than
    // like a Badge: on this row it is the same kind of thing — a constraint
    // you can see and remove — and a chip that reads as a label instead of a
    // control invites the reader to look for the control elsewhere.
    <span className="inline-flex h-11 shrink-0 items-center gap-1.5 rounded-lg border border-border bg-muted py-1 pr-1 pl-2.5 text-sm lg:h-[2.125rem]">
      <span className="text-muted-foreground">{label}</span>
      {isRange ? (
        // "1 Aug – 29 Aug 2026" rather than two chips of ISO bounds: the range
        // is what was asked for, and it is read far more often than it is
        // edited.
        <span>
          {formatDate(from)} – {formatDate(to)}
        </span>
      ) : (
        <>
          <span className="text-muted-foreground">{opLabel}</span>
          {showValue &&
            (col?.filterType === 'date' ? (
              <span>{formatDate(first.value)}</span>
            ) : col?.filterType === 'resource' && col.filterResource ? (
              <ResourceFilterValue value={first.value} config={col.filterResource} />
            ) : col?.filterType === 'tags' ? (
              <span>{parseFilterIds(first.value).join(', ')}</span>
            ) : col?.filterType === 'enum' && col.filterOptions ? (
              <span>
                {parseFilterIds(first.value)
                  .map((v) => col.filterOptions?.find((o) => o.value === v)?.label ?? v)
                  .join(', ')}
              </span>
            ) : (
              <span>{first.value}</span>
            ))}
        </>
      )}
      {/* 20px box around a 12px glyph: the chip's own height caps how large
          this can be, and the chips are spaced by `gap-2`, which is what the
          target-size rule asks for when the control itself is under 24px. */}
      <button
        type="button"
        aria-label={t('admin.components.table_toolbar.remove_filter')}
        className="ml-0.5 inline-flex size-5 shrink-0 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
        onClick={onRemove}
      >
        <XIcon className="size-3" />
      </button>
    </span>
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
  const tenantId = useTenantId()
  const ids = useMemo(() => parseFilterIds(value), [value])

  const { data } = useQuery({
    // Tenant-scope the cache key so chips don't resolve against another
    // tenant's hydrate results after a store or seller switch.
    queryKey: ['filter-chip', config.queryKey, tenantId, ids],
    queryFn: () => config.hydrate(ids),
    enabled: ids.length > 0,
    staleTime: 60_000,
  })

  if (ids.length === 0) return null

  const labels = ids.map((id) => {
    const record = data?.data.find((r) => r.id === id)
    return record ? config.getOptionLabel(record) : id
  })

  return <span>{labels.join(', ')}</span>
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
            <Button
              variant="outline"
              size="sm"
              className="h-11 lg:h-[2.125rem]"
              aria-label={t('admin.components.table_toolbar.sort_tooltip')}
            >
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
// Quick filters
// ============================================================================

/**
 * Always-visible control for one heavily-used filter.
 *
 * These write ordinary `FilterRule`s, so a status set here is indistinguishable
 * from one set in the popover — same URL state, same chips, same export. The
 * difference is only how many clicks it took.
 *
 * Unlike the popover, a quick filter applies on change rather than on Apply: a
 * single toggle is cheap to undo, so making the operator confirm it costs more
 * than it protects. The popover keeps its Apply, where several half-edited rows
 * would otherwise each fire a request.
 */
function QuickEnumFilter({
  column,
  filters,
  onFiltersChange,
}: {
  column: ColumnDef
  filters: FilterRule[]
  onFiltersChange: (filters: FilterRule[]) => void
}) {
  const { t } = useTranslation()
  // A boolean column carries no `filterOptions` — its two values are fixed, so
  // the control supplies them. `booleanLabels` names them where the domain has
  // better words than Yes and No.
  const options = useMemo(
    () =>
      column.filterType === 'boolean'
        ? [
            { value: 'true', label: column.booleanLabels?.true ?? t('admin.common.yes') },
            { value: 'false', label: column.booleanLabels?.false ?? t('admin.common.no') },
          ]
        : (column.filterOptions ?? []),
    [column.filterType, column.filterOptions, column.booleanLabels, t],
  )
  const existing = filters.find((f) => f.field === column.key && f.operator === 'in')

  // No rule means no constraint, which is every option — not none. Showing
  // "0/7" for an unfiltered list would read as "nothing matches".
  const selected = existing ? parseFilterIds(existing.value) : options.map((o) => o.value)
  const allSelected = selected.length === options.length

  const apply = useCallback(
    (values: string[]) => {
      const others = filters.filter((f) => !(f.field === column.key && f.operator === 'in'))
      // Selecting everything is the same as filtering by nothing, so drop the
      // rule instead of listing every value in the URL.
      if (values.length === 0 || values.length === options.length) {
        onFiltersChange(others)
        return
      }
      onFiltersChange([
        ...others,
        {
          id: existing?.id ?? crypto.randomUUID(),
          field: column.key,
          operator: 'in',
          value: values.join(','),
        },
      ])
    },
    [filters, column.key, options.length, existing?.id, onFiltersChange],
  )

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="h-11 gap-1.5 lg:h-[2.125rem]">
          <span className="text-muted-foreground">{column.label}</span>
          <span className="tabular-nums">
            {allSelected ? t('admin.common.all') : `${selected.length}/${options.length}`}
          </span>
          <ChevronDownIcon className="size-3.5 text-muted-foreground" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="min-w-52">
        {options.map((option) => (
          <DropdownMenuCheckboxItem
            key={option.value}
            checked={selected.includes(option.value)}
            onCheckedChange={(checked) =>
              apply(
                checked ? [...selected, option.value] : selected.filter((v) => v !== option.value),
              )
            }
          >
            <StatusDot status={option.value} />
            {option.label}
          </DropdownMenuCheckboxItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

/**
 * Relative date presets for one date column.
 *
 * A preset is a single choice rather than a range builder, which keeps it one
 * `FilterRule` and therefore one chip. Bounded ranges — "last month", or
 * anything picked by hand — need both ends, so those write two rules and read
 * back as two chips, which is honest about what was asked for.
 */
function QuickDateFilter({
  column,
  filters,
  onFiltersChange,
}: {
  column: ColumnDef
  filters: FilterRule[]
  onFiltersChange: (filters: FilterRule[]) => void
}) {
  const { t } = useTranslation()
  const store = useOptionalStore()
  // A panel with no store context (a seller's) falls back to the viewer's zone
  // rather than refusing to offer presets.
  const timezone = store?.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC'

  const from = filters.find((f) => f.field === column.key && f.operator === 'gteq')
  const to = filters.find((f) => f.field === column.key && f.operator === 'lteq')
  const active = matchDatePreset({ from: from?.value ?? null, to: to?.value ?? null }, timezone)
  // Seeded from what is applied, so reopening on a hand-picked range shows the
  // dates it is filtering by rather than an empty form.
  const [custom, setCustom] = useState<{ from: string; to: string } | null>(null)
  const [open, setOpen] = useState(false)

  /** Replace this column's bounds. Either end may be null for an open range. */
  const applyRange = useCallback(
    (rangeFrom: string | null, rangeTo: string | null) => {
      const others = filters.filter(
        (f) => !(f.field === column.key && (f.operator === 'gteq' || f.operator === 'lteq')),
      )
      const next: FilterRule[] = [...others]
      if (rangeFrom) {
        next.push({
          id: crypto.randomUUID(),
          field: column.key,
          operator: 'gteq',
          value: rangeFrom,
        })
      }
      if (rangeTo) {
        next.push({ id: crypto.randomUUID(), field: column.key, operator: 'lteq', value: rangeTo })
      }
      onFiltersChange(next)
    },
    [filters, column.key, onFiltersChange],
  )

  const apply = useCallback(
    (preset: DatePresetKey) => {
      const range = resolveDatePreset(preset, timezone)
      applyRange(range.from, range.to)
    },
    [timezone, applyRange],
  )

  // A Popover rather than a DropdownMenu: the custom branch holds date pickers
  // and a submit, which a menu's roving focus fights.
  return (
    <Popover
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        // Reopening starts on the preset list unless a custom range is what is
        // applied — then it opens on the range, so the dates stay editable.
        if (next) {
          setCustom(active === 'custom' ? { from: from?.value ?? '', to: to?.value ?? '' } : null)
        }
      }}
    >
      <PopoverTrigger asChild>
        <Button variant="outline" size="sm" className="h-11 gap-1.5 lg:h-[2.125rem]">
          <span className="text-muted-foreground">{column.label}</span>
          <span>{t(`admin.components.table_toolbar.date_presets.${active}`)}</span>
          <ChevronDownIcon className="size-3.5 text-muted-foreground" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="start" className="w-[min(320px,calc(100vw-1rem))] p-1">
        {custom ? (
          <div data-slot="filter-panel-controls" className="flex flex-col gap-2 p-2">
            <div className="flex flex-col gap-1">
              <span className="text-xs text-muted-foreground">
                {t('admin.components.table_toolbar.date_range_start')}
              </span>
              <StoreDatePicker
                value={custom.from || null}
                onChange={(next) => setCustom({ ...custom, from: next ?? '' })}
                placeholder={t('admin.components.table_toolbar.filter_date_placeholder')}
              />
            </div>
            <div className="flex flex-col gap-1">
              <span className="text-xs text-muted-foreground">
                {t('admin.components.table_toolbar.date_range_end')}
              </span>
              <StoreDatePicker
                value={custom.to || null}
                onChange={(next) => setCustom({ ...custom, to: next ?? '' })}
                placeholder={t('admin.components.table_toolbar.filter_date_placeholder')}
              />
            </div>
            <div className="flex justify-end gap-1.5">
              <Button variant="ghost" size="sm" onClick={() => setCustom(null)}>
                {t('admin.actions.back')}
              </Button>
              <Button
                size="sm"
                // Either bound alone is a valid filter — "everything since
                // March" is a question people ask.
                disabled={!custom.from && !custom.to}
                onClick={() => {
                  applyRange(custom.from || null, custom.to || null)
                  setOpen(false)
                }}
              >
                {t('admin.actions.apply')}
              </Button>
            </div>
          </div>
        ) : (
          <div className="flex flex-col">
            {DATE_PRESET_KEYS.map((preset) => (
              <button
                key={preset}
                type="button"
                data-slot="filter-panel-item"
                className="flex w-full items-center justify-between gap-2 rounded-lg px-2 py-1.5 text-left text-sm transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                onClick={() => {
                  apply(preset)
                  setOpen(false)
                }}
              >
                {t(`admin.components.table_toolbar.date_presets.${preset}`)}
                {active === preset && <CheckIcon className="size-3.5 shrink-0" />}
              </button>
            ))}
            {/* Without this the quick control is the only route to a date
                filter on tables whose every filterable column is a quick one —
                and it offers presets only, so a hand-picked range would be
                unreachable, and one restored from a URL would show as neither
                selected nor removable. */}
            <button
              type="button"
              data-slot="filter-panel-item"
              className="flex w-full items-center justify-between gap-2 rounded-lg px-2 py-1.5 text-left text-sm transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              onClick={() => setCustom({ from: from?.value ?? '', to: to?.value ?? '' })}
            >
              {t('admin.components.table_toolbar.date_presets.custom')}
              <ChevronRightIcon className="size-3.5 shrink-0 text-muted-foreground" />
            </button>
          </div>
        )}
      </PopoverContent>
    </Popover>
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
            <Button
              variant="outline"
              size="sm"
              className="h-11 lg:h-[2.125rem]"
              aria-label={t('admin.components.table_toolbar.columns_tooltip')}
            >
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
        <Button
          variant="ghost"
          size="sm"
          className="w-full justify-center"
          onClick={() => onVisibleColumnsChange(defaults)}
        >
          {t('admin.components.table_toolbar.reset_to_default')}
        </Button>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

// ============================================================================
// Filter Drawer
// ============================================================================
/**
 * Inline, searchable, multi-select list of a filter's candidate values.
 *
 * Tags and resources previously rendered a combobox, which opened its own
 * dropdown inside a panel that already had the room to show the options — a
 * popup over a popup, to display a list. Here the list is simply the panel's
 * body, filtered by the search box already in its header.
 *
 * Both types are "is any of" by nature, so there is no operator to choose:
 * ticking two tags means either, which is the only reading a set of tags has.
 */
function InlineValueList({
  column,
  tenantId,
  query,
  selected,
  onToggle,
}: {
  column: ColumnDef
  tenantId: string | undefined
  query: string
  selected: string[]
  onToggle: (value: string) => void
}) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const tagsClient = getApiClient().tags
  const isTags = column.filterType === 'tags'
  const isCurrency = column.filterType === 'currency'
  // `filterType: 'currency'` is only declared by tables in the operator's
  // dashboard, which always has a store. Reading it optionally keeps the panel
  // mountable in one that has none.
  const currencies = useOptionalStore()?.currencies ?? noCurrencies

  // Tags arrive as one list and are filtered client-side; resources are
  // searched server-side, since their vocabulary is unbounded.
  const tags = useQuery({
    // Tenant-scoped like the resource query below: tag vocabularies are
    // per-store, and a shared key would serve one store's tags to the next for
    // as long as the result stays fresh.
    queryKey: ['panel-tags', tenantId, column.taggableType],
    queryFn: () => tagsClient?.list({ taggable_type: column.taggableType as TaggableType }),
    enabled: isTags && isAuthenticated && Boolean(tagsClient),
    // One list, filtered client-side, and it rarely changes — worth holding
    // for the session so reopening the panel never refetches.
    staleTime: 5 * 60_000,
    gcTime: 30 * 60_000,
  })

  // Deferred so typing stays responsive: the input updates immediately while
  // the list re-renders at React's convenience, matching the resource picker
  // sheet. It lowers request volume under load rather than guaranteeing it —
  // React may still let every keystroke through on a fast machine. What keeps
  // that cheap is the cache: repeated prefixes are served from it, and only a
  // genuinely new query reaches the network.
  const deferredQuery = useDeferredValue(query)

  const resources = useQuery({
    // Tenant-scoped so a store or seller switch cannot reuse the previous
    // tenant's results.
    queryKey: ['panel-resource-filter', column.filterResource?.queryKey, tenantId, deferredQuery],
    queryFn: () => column.filterResource?.search(deferredQuery),
    enabled: !isTags && !isCurrency && Boolean(column.filterResource),
    // These lists are reference data an operator reopens repeatedly while
    // narrowing one list, and the result is small now that only the displayed
    // fields are requested. Holding it for the session keeps reopening the
    // panel instant; `gcTime` outlives the unmount between opens.
    staleTime: 5 * 60_000,
    gcTime: 30 * 60_000,
    // Keeps the previous matches on screen while the next query resolves, so
    // the list does not blank on every keystroke.
    //
    // Only within one field of one tenant: the second argument is the query
    // those results came from, so a change of store, seller or filter column
    // drops them instead of briefly offering another tenant's records as
    // though they were this one's.
    placeholderData: (previous, previousQuery) => {
      const [, previousResource, previousTenant] = (previousQuery?.queryKey ?? []) as unknown[]
      const sameScope =
        previousResource === column.filterResource?.queryKey && previousTenant === tenantId
      return sameScope ? previous : undefined
    },
  })

  const options = useMemo(() => {
    if (isCurrency) {
      const needle = query.trim().toLowerCase()
      return currencies
        .filter((code) => !needle || code.toLowerCase().includes(needle))
        .map((code) => ({ value: code, label: code }))
    }
    if (isTags) {
      const names = tags.data?.data?.map((tag) => tag.name) ?? []
      const needle = query.trim().toLowerCase()
      const matching = needle ? names.filter((name) => name.toLowerCase().includes(needle)) : names
      return matching.map((name) => ({ value: name, label: name }))
    }
    const config = column.filterResource
    if (!config) return []
    return (resources.data?.data ?? []).map((record) => ({
      value: record.id,
      label: config.getOptionLabel(record),
    }))
  }, [isCurrency, currencies, isTags, tags.data, resources.data, column.filterResource, query])

  // Selected values ride at the top so a choice made before searching does not
  // disappear the moment the query stops matching it.
  const ordered = useMemo(() => {
    const chosen = options.filter((option) => selected.includes(option.value))
    const rest = options.filter((option) => !selected.includes(option.value))
    // Not truncated: a list cut at ten looks like a list of ten, and a
    // vocabulary of forty tags would silently lose thirty with nothing on
    // screen to say so. The container scrolls instead, so the scrollbar
    // reports how much more there is — and searching narrows it.
    return [...chosen, ...rest]
  }, [options, selected])

  if (!isCurrency && (tags.isLoading || resources.isLoading)) {
    return (
      <p className="px-2 py-6 text-center text-sm text-muted-foreground">
        {t('admin.common.loading')}
      </p>
    )
  }

  if (ordered.length === 0) {
    return (
      <p className="px-2 py-6 text-center text-sm text-muted-foreground">
        {t('admin.common.no_results')}
      </p>
    )
  }

  return (
    <>
      {ordered.map((option) => (
        <button
          key={option.value}
          type="button"
          className="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left text-sm transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
          onClick={() => onToggle(option.value)}
        >
          <Checkbox checked={selected.includes(option.value)} className="pointer-events-none" />
          <span className="truncate">{option.label}</span>
        </button>
      ))}
    </>
  )
}

/**
 * The advanced filter panel, in two stages.
 *
 * Stage one lists the fields. Stage two commits to one of them and shows its
 * values, with the field name kept as a select in the header so switching
 * subject is one click rather than a trip back.
 *
 * One filter at a time, deliberately: filters compose by being applied in
 * succession, and each one lands as a chip on the toolbar row, so the row is
 * the list of what is active. A panel that also held several half-built rows
 * duplicated that list in a second place, in a different notation.
 */
function FilterPanel({
  columns,
  allColumns,
  filters,
  onApply,
  onChange,
  onClose,
}: {
  /** Fields offered in the list — excludes those with a quick control. */
  columns: ColumnDef[]
  /** Every filterable field, for the field-switch select once one is chosen. */
  allColumns: ColumnDef[]
  filters: FilterRule[]
  /** Commit and close — for the filters that are finished in one action. */
  onApply: (filters: FilterRule[]) => void
  /** Update without closing — for a multi-select the user is still building. */
  onChange: (filters: FilterRule[]) => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  const tenantId = useTenantId()
  const store = useOptionalStore()
  const timezone = store?.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC'
  // The field being built, or null while the field list is showing.
  const [field, setField] = useState<string | null>(null)
  const [operator, setOperator] = useState('')
  const [value, setValue] = useState('')
  const [query, setQuery] = useState('')
  // Set once the user picks "custom" from the date presets, revealing the two
  // date fields. Kept separate from `value` so backing out of custom does not
  // strand a half-entered range.
  const [customRange, setCustomRange] = useState<{ from: string; to: string } | null>(null)

  // Resolved against every field, not just the offered ones: the switch
  // select can land on a quick-filtered field the list deliberately omits.
  const column = allColumns.find((c) => c.key === field)
  const type = column?.filterType ?? 'string'
  const operators = useMemo(
    () => getOperators(type).map((op) => ({ value: op.value, label: t(op.labelKey) })),
    [type, t],
  )
  // The switch select offers what the field list offered, plus whatever is
  // currently chosen. Listing every filterable field would put the
  // quick-filtered ones — which have their own control on the row — back into
  // the panel, so "Date" would appear twice on screen at once.
  const switchColumns = useMemo(() => {
    const offered = columns.slice()
    if (field && !offered.some((c) => c.key === field)) {
      const current = allColumns.find((c) => c.key === field)
      if (current) offered.unshift(current)
    }
    return offered
  }, [columns, allColumns, field])
  const fieldItems = useMemo(
    () => switchColumns.map((c) => ({ value: c.key, label: c.label })),
    [switchColumns],
  )

  // Types whose values are a fixed list the panel can render inline. Anything
  // else needs its own control (an autocomplete, a date picker, a text box),
  // which is what the second branch below draws.
  // Types whose values are chosen from a list rather than typed. `multi` ones
  // accumulate a set and need an explicit Apply; the single ones commit on the
  // click that picks them.
  const multi = type === 'tags' || type === 'resource' || type === 'currency'
  // Dates are their own shape: a list of relative presets, with the calendar
  // behind "custom". Same presets the quick filter offers, so a range means
  // the same thing wherever it was set.
  const dated = type === 'date'
  const listed = type === 'enum' || type === 'boolean' || multi
  // The header search filters the list below it, so it earns its place only
  // when there is a list: the fields, or a list-shaped type's values.
  const searchable = (!field || listed) && !dated
  const listOptions = useMemo(() => {
    const options =
      type === 'boolean'
        ? [
            { value: 'true', label: column?.booleanLabels?.true ?? t('admin.common.yes') },
            { value: 'false', label: column?.booleanLabels?.false ?? t('admin.common.no') },
          ]
        : (column?.filterOptions ?? [])
    if (!query.trim()) return options
    const needle = query.trim().toLowerCase()
    return options.filter((o) => o.label.toLowerCase().includes(needle))
  }, [type, column?.filterOptions, column?.booleanLabels, query, t])

  const visibleFields = useMemo(() => {
    if (!query.trim()) return columns
    const needle = query.trim().toLowerCase()
    return columns.filter((c) => c.label.toLowerCase().includes(needle))
  }, [columns, query])

  function chooseField(key: string) {
    const col = allColumns.find((c) => c.key === key)
    const firstOperator = getOperators(col?.filterType ?? 'string')[0].value
    setField(key)
    setOperator(firstOperator)
    // Seed from what is already applied, so reopening a multi-select shows the
    // values it is filtering by. Without this the list reads as empty and the
    // next tick would replace the existing set rather than extend it.
    const applied = filters.find((f) => f.field === key && f.operator === 'in')
    setValue(applied?.value ?? '')
    setQuery('')
  }

  /**
   * Apply this filter and close.
   *
   * Replaces any rule already set on the same field and operator rather than
   * adding a second: picking "Status is Active", then reopening and picking
   * "Status is Draft", would otherwise leave two `eq` rules that the server
   * ANDs together into nothing. Rules on the same field with a *different*
   * operator survive — `created_at after X` and `created_at before Y` are a
   * range, not a contradiction.
   */
  function commit(nextValue: string, nextOperator = operator) {
    if (!field) return
    if (!noValueOperators.includes(nextOperator) && nextValue.trim() === '') return
    const others = filters.filter((f) => !(f.field === field && f.operator === nextOperator))
    onApply([
      ...others,
      { id: crypto.randomUUID(), field, operator: nextOperator, value: nextValue },
    ])
  }

  /** Replace this field's bounds with a preset's, and close. */
  function commitDatePreset(preset: DatePresetKey) {
    if (!field) return
    const range = resolveDatePreset(preset, timezone)
    const others = filters.filter(
      (f) => !(f.field === field && (f.operator === 'gteq' || f.operator === 'lteq')),
    )
    const next = [...others]
    if (range.from) {
      next.push({ id: crypto.randomUUID(), field, operator: 'gteq', value: range.from })
    }
    if (range.to) {
      next.push({ id: crypto.randomUUID(), field, operator: 'lteq', value: range.to })
    }
    onApply(next)
  }

  /**
   * Apply a multi-select as it is ticked, keeping the panel open.
   *
   * Replaces this field's rule rather than appending, so ticking three tags
   * leaves one rule listing three values instead of three rules — and
   * unticking the last one removes it, rather than leaving an empty rule that
   * would match nothing.
   */
  function toggleValue(option: string) {
    if (!field) return
    const current = parseFilterIds(value)
    const next = current.includes(option)
      ? current.filter((v) => v !== option)
      : [...current, option]
    setValue(next.join(','))

    const others = filters.filter((f) => !(f.field === field && f.operator === 'in'))
    onChange(
      next.length === 0
        ? others
        : [...others, { id: crypto.randomUUID(), field, operator: 'in', value: next.join(',') }],
    )
  }

  return (
    <div className="flex flex-col">
      {/* Header. Before a field is chosen this is a label and a search box over
          the field list; after, the label becomes a select, so changing subject
          costs one click instead of backing out. */}
      <div className="flex items-stretch border-b">
        {field ? (
          <Select items={fieldItems} value={field} onValueChange={chooseField}>
            <SelectTrigger
              size="sm"
              // Sits flush in the panel's top-left corner, so it drops the
              // standalone-field focus treatment: a blue border and a 3px
              // outer glow paint past the panel's rounded edge and read as a
              // rendering fault. A background change carries focus instead,
              // which stays inside the element's own box.
              className="w-auto shrink-0 rounded-none border-0 border-r bg-transparent shadow-none focus:border-border focus:bg-accent focus:shadow-none"
            >
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {switchColumns.map((c) => (
                <SelectItem key={c.key} value={c.key}>
                  {c.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        ) : (
          <span className="flex shrink-0 items-center border-r px-3 py-2 text-sm font-medium">
            {t('admin.components.table_toolbar.filter_by')}
          </span>
        )}
        {/* Only where it filters something: a list of fields, or a list of
            values. The other value types bring their own input — a resource
            autocomplete, a date picker, a text box — and a second search box
            above one of those searches nothing. */}
        {searchable ? (
          <Input
            autoFocus
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder={t('admin.components.table_toolbar.filter_to_placeholder')}
            className="min-w-0 flex-1 rounded-none border-0 shadow-none focus:shadow-none"
          />
        ) : (
          <span className="flex-1" />
        )}
        <Button onClick={onClose} size="icon-sm" variant="ghost" className="m-1 shrink-0">
          <XIcon className="size-4" />
        </Button>
      </div>

      {/* Scrolls, and says so. `overscroll-contain` keeps a flick at the end of
          the list from scrolling the page behind the panel; the themed
          scrollbar the popover supplies is what tells the reader there is more
          below, since the rows themselves end flush at the container's edge. */}
      <div className="max-h-[320px] overflow-y-auto overscroll-contain p-1 themed-scrollbar">
        {/* Stage one: pick a subject. */}
        {!field &&
          visibleFields.map((col) => (
            <button
              key={col.key}
              type="button"
              data-slot="filter-panel-item"
              className="flex w-full items-center justify-between gap-2 rounded-md px-2 py-1.5 text-left text-sm transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              onClick={() => chooseField(col.key)}
            >
              {col.label}
              <ChevronRightIcon className="size-3.5 shrink-0 text-muted-foreground" />
            </button>
          ))}

        {/* Stage two, list-shaped types: the values themselves, one click to
            apply. No operator control — "is" is the only thing a list of
            values can mean, and offering "is not" here would double the list's
            length for a case the panel's other branch already covers. */}
        {field &&
          listed &&
          !multi &&
          listOptions.map((option) => (
            <button
              key={option.value}
              type="button"
              data-slot="filter-panel-item"
              className="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left text-sm transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              onClick={() => commit(option.value, 'eq')}
            >
              {/* Booleans get one too: their values carry the same
                  green/red reading as any other state. */}
              {(type === 'enum' || type === 'boolean') && <StatusDot status={option.value} />}
              {option.label}
            </button>
          ))}

        {/* Tags and resources: several values at once. Each tick applies
            immediately and the list stays open, so narrowing to two sellers is
            two clicks rather than two clicks and a confirmation — the table
            behind the panel is already showing the result. */}
        {field && multi && column && (
          <InlineValueList
            column={column}
            tenantId={tenantId}
            query={query}
            selected={parseFilterIds(value)}
            onToggle={toggleValue}
          />
        )}

        {/* Stage two, dates: the same relative presets the quick filter
            offers, so a range means the same thing wherever it was set.
            "Custom" swaps in two date fields rather than opening a third
            popup on top of this one. */}
        {field && dated && !customRange && (
          <>
            {DATE_PRESET_KEYS.map((preset) => (
              <button
                key={preset}
                type="button"
                data-slot="filter-panel-item"
                className="flex w-full items-center rounded-lg px-2 py-1.5 text-left text-sm transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                onClick={() => commitDatePreset(preset)}
              >
                {t(`admin.components.table_toolbar.date_presets.${preset}`)}
              </button>
            ))}
            <button
              type="button"
              data-slot="filter-panel-item"
              className="flex w-full items-center justify-between gap-2 rounded-md px-2 py-1.5 text-left text-sm transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              onClick={() => setCustomRange({ from: '', to: '' })}
            >
              {t('admin.components.table_toolbar.date_presets.custom')}
              <ChevronRightIcon className="size-3.5 shrink-0 text-muted-foreground" />
            </button>
          </>
        )}

        {field && dated && customRange && (
          <div data-slot="filter-panel-controls" className="flex flex-col gap-2 p-2">
            <div className="flex flex-col gap-1">
              <span className="text-xs text-muted-foreground">
                {t('admin.components.table_toolbar.date_range_start')}
              </span>
              <StoreDatePicker
                value={customRange.from || null}
                onChange={(next) => setCustomRange({ ...customRange, from: next ?? '' })}
                placeholder={t('admin.components.table_toolbar.filter_date_placeholder')}
              />
            </div>
            <div className="flex flex-col gap-1">
              <span className="text-xs text-muted-foreground">
                {t('admin.components.table_toolbar.date_range_end')}
              </span>
              <StoreDatePicker
                value={customRange.to || null}
                onChange={(next) => setCustomRange({ ...customRange, to: next ?? '' })}
                placeholder={t('admin.components.table_toolbar.filter_date_placeholder')}
              />
            </div>
            <div className="flex justify-end gap-1.5">
              <Button variant="ghost" size="sm" onClick={() => setCustomRange(null)}>
                {t('admin.actions.back')}
              </Button>
              <Button
                size="sm"
                // Either bound alone is a valid filter — "everything since
                // March" is a question people ask.
                disabled={!customRange.from && !customRange.to}
                onClick={() => {
                  if (!field) return
                  const others = filters.filter(
                    (f) => !(f.field === field && (f.operator === 'gteq' || f.operator === 'lteq')),
                  )
                  const next = [...others]
                  if (customRange.from) {
                    next.push({
                      id: crypto.randomUUID(),
                      field,
                      operator: 'gteq',
                      value: customRange.from,
                    })
                  }
                  if (customRange.to) {
                    next.push({
                      id: crypto.randomUUID(),
                      field,
                      operator: 'lteq',
                      value: customRange.to,
                    })
                  }
                  onApply(next)
                }}
              >
                {t('admin.actions.apply')}
              </Button>
            </div>
          </div>
        )}

        {/* Stage two, everything else: an operator and a value. The operator
            lives here rather than in the header because it only exists for
            these types — a text column's "contains" versus "starts with" is a
            real choice, where a status has nothing to choose. */}
        {field && !listed && !dated && (
          <div data-slot="filter-panel-controls" className="flex flex-col gap-2 p-2">
            <Select items={operators} value={operator} onValueChange={setOperator}>
              <SelectTrigger size="sm">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {operators.map((op) => (
                  <SelectItem key={op.value} value={op.value}>
                    {op.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            {/* Everything picked from a list — currency, tags, resources — or
                from a calendar is handled above; this branch is only the types
                you type into. */}
            {!noValueOperators.includes(operator) && (
              <Input
                type={type === 'number' ? 'number' : 'text'}
                placeholder={t('admin.components.table_toolbar.filter_text_placeholder')}
                value={value}
                onChange={(event) => setValue(event.target.value)}
                // Enter applies, so a text filter is type-and-go rather than
                // type-then-reach-for-the-button.
                onKeyDown={(event) => {
                  if (event.key === 'Enter') {
                    event.preventDefault()
                    commit(value)
                  }
                }}
              />
            )}

            {/* Right-aligned rather than stretched: a full-width black bar
                reads as the panel's primary purpose, when it is one step in a
                filter the operator is still composing. */}
            <div className="flex justify-end">
              <Button size="sm" onClick={() => commit(value)}>
                {t('admin.actions.apply')}
              </Button>
            </div>
          </div>
        )}

        {/* Nothing matched the search — say so rather than showing a blank
            panel that reads as broken. */}
        {((!field && visibleFields.length === 0) ||
          (field && listed && !multi && listOptions.length === 0)) && (
          <p className="px-2 py-6 text-center text-sm text-muted-foreground">
            {t('admin.common.no_results')}
          </p>
        )}
      </div>
    </div>
  )
}

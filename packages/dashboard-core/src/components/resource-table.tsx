import {
  closestCenter,
  DndContext,
  type DragEndEvent,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import {
  Card,
  CardContent,
  Checkbox,
  cn,
  DragHandle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Pagination,
  type PaginationMeta,
  Table,
  TableBody,
  TableCell,
  TableEmpty,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import {
  type CSSProperties,
  type ReactNode,
  useCallback,
  useDeferredValue,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useAuth } from '../hooks/use-auth'
import { filtersToRansack } from '../lib/filters-to-ransack'
import {
  type ColumnDef,
  type FilterRule,
  getDefaultColumnKeys,
  getDisplayableColumns,
  getTable,
  type SortOption,
} from '../lib/table-registry'
import { type BulkAction, BulkActionBar } from './bulk-action-bar'
import { TableToolbar } from './table-toolbar'

// ============================================================================
// Search schema — shared by all resource table routes
// ============================================================================

const filterSchema = z.object({
  id: z.string(),
  field: z.string(),
  operator: z.string(),
  value: z.string(),
})

export const resourceSearchSchema = z.object({
  page: z.coerce.number().optional().default(1),
  limit: z.coerce.number().optional(),
  sort: z.string().optional(),
  dir: z.enum(['asc', 'desc']).optional(),
  search: z.string().optional(),
  filters: z
    .preprocess((val) => {
      if (typeof val === 'string') {
        try {
          return JSON.parse(val)
        } catch {
          return []
        }
      }
      return val ?? []
    }, z.array(filterSchema))
    .optional()
    .default([]),
  columns: z
    .preprocess((val) => {
      if (typeof val === 'string') return val.split(',')
      return val
    }, z.array(z.string()))
    .optional(),
})

export type ResourceSearch = z.infer<typeof resourceSearchSchema>

// ============================================================================
// Props
// ============================================================================

/**
 * Per-render context handed to the `actions` render-prop. Gives toolbar
 * actions enough state to act on the *current* table view — needed for
 * features like "export filtered records" that have to mirror what the user
 * is looking at.
 */
export interface ResourceActionsContext {
  filters: FilterRule[]
  search: string
  searchParam: string
  /** All columns (incl. filter-only) — needed by `filtersToRansack`. */
  columns: ColumnDef[]
  /** Total record count for the active filter, or `undefined` while loading. */
  totalCount: number | undefined
}

interface ResourceTableProps<T> {
  /** Registry key (e.g., 'products') */
  tableKey: string
  /** TanStack Query key prefix (e.g., 'products') */
  queryKey: string
  /** Function that calls the SDK to fetch data */
  queryFn: (params: Record<string, unknown>) => Promise<{ data: T[]; meta: PaginationMeta }>
  /** Current search params from the route */
  searchParams: ResourceSearch
  /** Title displayed in the toolbar header. Overrides the table definition's title. */
  title?: string
  /** Default params always sent with every request (e.g., { complete: 1 } for orders) */
  defaultParams?: Record<string, unknown>
  /**
   * Actions to render in the toolbar (e.g., "Add Product" button). Either a
   * static node, or a function that receives the current table state — use
   * the function form for actions that depend on filters/search (e.g. CSV
   * export of the active view).
   */
  actions?: ReactNode | ((ctx: ResourceActionsContext) => ReactNode)
  /**
   * When set, rows can be drag-reordered. The handler receives the moved
   * row's id and its new 1-indexed position; the server is expected to
   * handle the rest via `acts_as_list` (other rows shift around). Drag
   * is only active when the table is sorted ascending by `positionField`
   * (default: `position`) — otherwise reordering would be meaningless.
   */
  reorder?: ReorderConfig<T>
  /**
   * Bulk operations available against selected rows. When present, the
   * table renders a leading checkbox column and a sticky action bar
   * appears once any row is selected. Mutually exclusive with `reorder`
   * — the leading column is already taken by the drag handle.
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  bulkActions?: BulkAction<any>[]
  /**
   * Per-row action menu. When set, a trailing cell renders whatever the
   * function returns (typically a `<RowActions>` kebab). Works alongside
   * `reorder` — the drag handle sits on the leading edge, the actions
   * menu on the trailing edge.
   */
  rowActions?: (row: T) => ReactNode
}

export interface ReorderConfig<T> {
  onReorder: (id: string, position: number, row: T) => Promise<unknown> | unknown
  /** Defaults to `'position'`. Override for resources that sort on a different column. */
  positionField?: string
}

// ============================================================================
// Component
// ============================================================================

export function ResourceTable<T extends Record<string, any>>({
  tableKey,
  queryKey,
  queryFn,
  searchParams,
  title,
  defaultParams,
  actions,
  reorder,
  bulkActions,
  rowActions,
}: ResourceTableProps<T>) {
  const table = getTable<T>(tableKey)
  const { t } = useTranslation()
  const { token } = useAuth()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const selectionEnabled = !!bulkActions?.length && !reorder
  const rowActionsEnabled = !!rowActions
  const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set())
  // Used by +BulkActionBar+ to anchor itself within the table card on
  // desktop (instead of free-floating at the viewport bottom).
  const cardRef = useRef<HTMLDivElement | null>(null)

  const {
    page,
    limit,
    sort: urlSort,
    dir: urlDir,
    search,
    filters,
    columns: urlColumns,
  } = searchParams

  // When the table is reorderable, sort is locked to the position field
  // ascending — anything else makes drag-and-drop meaningless. Otherwise
  // fall through to the URL params, then the table's declared default,
  // then a sensible fallback.
  const positionField = reorder?.positionField ?? 'position'
  const defaultSort = table.defaultSort ?? {
    field: 'updated_at',
    direction: 'desc' as const,
  }
  const sort = reorder ? positionField : (urlSort ?? defaultSort.field)
  const dir: 'asc' | 'desc' = reorder ? 'asc' : (urlDir ?? defaultSort.direction)

  const [searchInput, setSearchInput] = useState(search ?? '')
  const deferredSearch = useDeferredValue(searchInput)

  const displayableColumns = getDisplayableColumns(table)
  const defaultColumnKeys = getDefaultColumnKeys(table)
  const visibleColumnKeys = urlColumns ?? defaultColumnKeys

  const visibleColumns = displayableColumns.filter((c) => visibleColumnKeys.includes(c.key))

  // Build API params
  const sortString = dir === 'desc' ? `-${sort}` : sort

  const { data, isLoading } = useQuery({
    queryKey: [queryKey, { page, limit, sort: sortString, search: deferredSearch, filters }],
    queryFn: () => {
      const params: Record<string, unknown> = {
        page,
        sort: sortString,
        ...defaultParams,
      }

      if (limit) {
        params.limit = limit
      }

      if (deferredSearch) {
        const searchParam = table.searchParam ?? 'name_cont'
        params[searchParam] = deferredSearch
      }

      Object.assign(params, filtersToRansack(filters as FilterRule[], table.columns))

      return queryFn(params)
    },
    enabled: !!token,
  })

  const fetchedRows = data?.data ?? []
  const meta = data?.meta

  // Selection is per-page and ephemeral. Wipe it whenever the user pages,
  // re-sorts, filters, or searches — keeping IDs from prior pages would let
  // them silently apply a bulk op to rows the user can no longer see.
  // biome-ignore lint/correctness/useExhaustiveDependencies: intentional reset on visible-set change
  useEffect(() => {
    if (selectionEnabled) {
      setSelectedIds((prev) => (prev.size === 0 ? prev : new Set()))
    }
  }, [page, sortString, deferredSearch, filters, selectionEnabled])

  const reorderActive = !!reorder

  // Mirror the fetched rows in local state while reordering so we can swap
  // them optimistically on drop. Only allocated when reorder is active —
  // otherwise the table reads `fetchedRows` straight through. The mirror
  // tracks the upstream cache by identity; TanStack returns a new array
  // reference on every refetch, so this useEffect runs whenever data updates.
  const [localRows, setLocalRows] = useState<T[]>(fetchedRows)
  useEffect(() => {
    if (reorderActive) setLocalRows(fetchedRows)
  }, [fetchedRows, reorderActive])

  const rows = reorderActive ? localRows : fetchedRows

  // dnd-kit sensors: pointer for mouse/touch (5px activation distance keeps
  // brief clicks on row content from starting a drag), keyboard for a11y.
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const handleDragEnd = useCallback(
    async (event: DragEndEvent) => {
      const { active, over } = event
      if (!over || active.id === over.id || !reorder) return

      const fromIndex = localRows.findIndex((r) => r.id === active.id)
      const toIndex = localRows.findIndex((r) => r.id === over.id)
      if (fromIndex === -1 || toIndex === -1) return

      const moved = localRows[fromIndex]
      const next = arrayMove(localRows, fromIndex, toIndex)
      setLocalRows(next)

      try {
        // 1-indexed position; acts_as_list shifts the rest server-side.
        await reorder.onReorder(String(active.id), toIndex + 1, moved)
      } catch {
        // Rollback on failure — the next refetch will reconcile anyway.
        setLocalRows(localRows)
      }
    },
    [localRows, reorder],
  )

  // Navigation helpers
  function updateSearch(updates: Record<string, unknown>) {
    navigate({
      search: (prev: Record<string, unknown>) => ({ ...prev, ...updates }) as never,
    })
  }

  function handleSearchChange(value: string) {
    setSearchInput(value)
    updateSearch({ search: value || undefined, page: 1 })
  }

  function handleSortChange(s: SortOption) {
    updateSearch({ sort: s.field, dir: s.direction, page: 1 })
  }

  function handleFiltersChange(f: FilterRule[]) {
    updateSearch({
      filters: f.length > 0 ? JSON.stringify(f) : undefined,
      page: 1,
    })
  }

  function handleColumnsChange(cols: string[]) {
    const isDefault =
      cols.length === defaultColumnKeys.length && cols.every((c) => defaultColumnKeys.includes(c))
    updateSearch({ columns: isDefault ? undefined : cols.join(',') })
  }

  const pageIds = useMemo(() => (data?.data ?? []).map((r) => String((r as any).id)), [data])
  const allPageSelected = pageIds.length > 0 && pageIds.every((id) => selectedIds.has(id))
  const somePageSelected = pageIds.some((id) => selectedIds.has(id)) && !allPageSelected

  function toggleRow(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  function togglePage() {
    setSelectedIds((prev) => {
      if (allPageSelected) {
        const next = new Set(prev)
        for (const id of pageIds) next.delete(id)
        return next
      }
      const next = new Set(prev)
      for (const id of pageIds) next.add(id)
      return next
    })
  }

  // Header columns for price-like right-aligned columns
  const headerColumns = visibleColumns.map((col) => {
    const isRightAligned = col.className?.includes('text-right')
    return {
      ...col,
      headerClassName: isRightAligned ? 'text-right' : undefined,
    }
  })

  const resolvedActions =
    typeof actions === 'function'
      ? actions({
          filters: filters as FilterRule[],
          search: deferredSearch,
          searchParam: table.searchParam ?? 'name_cont',
          columns: table.columns,
          totalCount: meta?.count,
        })
      : actions

  return (
    <Card ref={cardRef} className="rounded-xl">
      <TableToolbar
        columns={displayableColumns}
        visibleColumns={visibleColumnKeys}
        onVisibleColumnsChange={handleColumnsChange}
        search={searchInput}
        onSearchChange={handleSearchChange}
        searchPlaceholder={table.searchPlaceholder ?? 'Search...'}
        sort={{ field: sort, direction: dir }}
        onSortChange={handleSortChange}
        filters={filters as FilterRule[]}
        onFiltersChange={handleFiltersChange}
        allColumns={table.columns}
        title={title ?? table.title}
        actions={resolvedActions}
        hideSort={reorderActive}
      />
      <CardContent className="p-0">
        {reorderActive ? (
          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={handleDragEnd}
          >
            <SortableContext
              items={rows.map((r) => (r as any).id)}
              strategy={verticalListSortingStrategy}
            >
              <Table>
                <TableHeader>
                  <tr>
                    <TableHead className="w-8" />
                    {headerColumns.map((col) => (
                      <TableHead key={col.key} className={col.headerClassName}>
                        {col.label}
                      </TableHead>
                    ))}
                    {rowActionsEnabled && (
                      <TableHead className="w-12">
                        <span className="sr-only">{t('admin.row_actions.menu_label')}</span>
                      </TableHead>
                    )}
                  </tr>
                </TableHeader>
                <TableBody>
                  {isLoading ? (
                    <TableEmpty colSpan={visibleColumns.length + 1 + (rowActionsEnabled ? 1 : 0)}>
                      Loading...
                    </TableEmpty>
                  ) : rows.length === 0 ? (
                    <TableEmpty colSpan={visibleColumns.length + 1 + (rowActionsEnabled ? 1 : 0)}>
                      <Empty className="border-0 p-0">
                        <EmptyHeader>
                          {table.emptyIcon && (
                            <EmptyMedia variant="icon">{table.emptyIcon}</EmptyMedia>
                          )}
                          <EmptyTitle>{table.emptyMessage ?? 'No results found'}</EmptyTitle>
                          {(deferredSearch || (filters as FilterRule[]).length > 0) && (
                            <EmptyDescription>
                              Try adjusting your search or filters
                            </EmptyDescription>
                          )}
                        </EmptyHeader>
                      </Empty>
                    </TableEmpty>
                  ) : (
                    rows.map((row) => (
                      <SortableRow
                        key={(row as any).id}
                        row={row}
                        columns={visibleColumns}
                        rowActions={rowActions}
                      />
                    ))
                  )}
                </TableBody>
              </Table>
            </SortableContext>
          </DndContext>
        ) : (
          <Table>
            <TableHeader>
              <tr>
                {selectionEnabled && (
                  <TableHead className="w-8">
                    <Checkbox
                      checked={allPageSelected}
                      indeterminate={somePageSelected}
                      onCheckedChange={togglePage}
                      aria-label={t('admin.a11y.select_all_rows')}
                    />
                  </TableHead>
                )}
                {headerColumns.map((col) => (
                  <TableHead key={col.key} className={col.headerClassName}>
                    {col.label}
                  </TableHead>
                ))}
                {rowActionsEnabled && (
                  <TableHead className="w-12">
                    <span className="sr-only">{t('admin.row_actions.menu_label')}</span>
                  </TableHead>
                )}
              </tr>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableEmpty
                  colSpan={
                    visibleColumns.length + (selectionEnabled ? 1 : 0) + (rowActionsEnabled ? 1 : 0)
                  }
                >
                  Loading...
                </TableEmpty>
              ) : rows.length === 0 ? (
                <TableEmpty
                  colSpan={
                    visibleColumns.length + (selectionEnabled ? 1 : 0) + (rowActionsEnabled ? 1 : 0)
                  }
                >
                  <Empty className="border-0 p-0">
                    <EmptyHeader>
                      {table.emptyIcon && <EmptyMedia variant="icon">{table.emptyIcon}</EmptyMedia>}
                      <EmptyTitle>{table.emptyMessage ?? 'No results found'}</EmptyTitle>
                      {(deferredSearch || (filters as FilterRule[]).length > 0) && (
                        <EmptyDescription>Try adjusting your search or filters</EmptyDescription>
                      )}
                    </EmptyHeader>
                  </Empty>
                </TableEmpty>
              ) : (
                rows.map((row, i) => {
                  const rowId = String((row as any).id ?? i)
                  const isSelected = selectionEnabled && selectedIds.has(rowId)
                  return (
                    <TableRow
                      key={(row as any).id ?? i}
                      className={isSelected ? 'bg-muted/40' : undefined}
                    >
                      {selectionEnabled && (
                        <TableCell className="w-8">
                          <Checkbox
                            checked={isSelected}
                            onCheckedChange={() => toggleRow(rowId)}
                            aria-label={t('admin.a11y.select_row')}
                          />
                        </TableCell>
                      )}
                      {visibleColumns.map((col) => (
                        <TableCell key={col.key} className={col.className}>
                          {col.render ? col.render(row) : String((row as any)[col.key] ?? '—')}
                        </TableCell>
                      ))}
                      {rowActionsEnabled && (
                        <TableCell className="w-12 text-right">{rowActions?.(row)}</TableCell>
                      )}
                    </TableRow>
                  )
                })
              )}
            </TableBody>
          </Table>
        )}
        {meta && (
          <Pagination
            meta={meta}
            onPageChange={(p) => updateSearch({ page: p })}
            onPageSizeChange={(size) => updateSearch({ limit: size, page: 1 })}
          />
        )}
        {selectionEnabled && (
          <BulkActionBar
            selectedIds={Array.from(selectedIds)}
            actions={bulkActions!}
            anchorRef={cardRef}
            onClear={() => setSelectedIds(new Set())}
            onDone={() => {
              setSelectedIds(new Set())
              queryClient.invalidateQueries({ queryKey: [queryKey] })
            }}
          />
        )}
      </CardContent>
    </Card>
  )
}

// ============================================================================
// SortableRow — internal row that wires dnd-kit's listeners to a leading
// drag-handle cell. Mirrors the styling of <TableRow> from data-table.tsx.
// ============================================================================

function SortableRow<T extends Record<string, any>>({
  row,
  columns,
  rowActions,
}: {
  row: T
  columns: ColumnDef[]
  rowActions?: (row: T) => ReactNode
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: row.id,
  })

  const style: CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  return (
    <tr
      ref={setNodeRef}
      style={style}
      className={cn(
        'group/row hover:bg-muted/60 last:*:border-b-0',
        isDragging && 'relative z-10 opacity-70',
      )}
    >
      <TableCell className="w-8 touch-none">
        <DragHandle attributes={attributes} listeners={listeners} />
      </TableCell>
      {columns.map((col) => (
        <TableCell key={col.key} className={col.className}>
          {col.render ? col.render(row) : String((row as any)[col.key] ?? '—')}
        </TableCell>
      ))}
      {rowActions && <TableCell className="w-12 text-right">{rowActions(row)}</TableCell>}
    </tr>
  )
}

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
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import {
  type CSSProperties,
  type ReactNode,
  useCallback,
  useDeferredValue,
  useEffect,
  useState,
} from 'react'
import { z } from 'zod/v4'
import { DragHandle } from '@/components/spree/drag-handle'
import { EmptyState } from '@/components/spree/empty-state'
import { TableToolbar } from '@/components/spree/table-toolbar'
import { Card, CardContent } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableEmpty,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/data-table'
import { Pagination, type PaginationMeta } from '@/components/ui/pagination'
import { useAuth } from '@/hooks/use-auth'
import { filtersToRansack } from '@/lib/filters-to-ransack'
import {
  type ColumnDef,
  type FilterRule,
  getDefaultColumnKeys,
  getDisplayableColumns,
  getTable,
  type SortOption,
} from '@/lib/table-registry'
import { cn } from '@/lib/utils'

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
}: ResourceTableProps<T>) {
  const table = getTable<T>(tableKey)
  const { token } = useAuth()
  const navigate = useNavigate()

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

  // Mirror the fetched rows in local state while reordering so we can swap
  // them optimistically on drop. The mirror tracks the upstream cache by
  // identity — TanStack returns a new array reference on every refetch, so
  // this useEffect runs whenever the server data updates.
  const [localRows, setLocalRows] = useState<T[]>(fetchedRows)
  useEffect(() => {
    setLocalRows(fetchedRows)
  }, [fetchedRows])

  const reorderActive = !!reorder
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
    <Card className="rounded-2xl">
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
                  </tr>
                </TableHeader>
                <TableBody>
                  {isLoading ? (
                    <TableEmpty colSpan={visibleColumns.length + 1}>Loading...</TableEmpty>
                  ) : rows.length === 0 ? (
                    <TableEmpty colSpan={visibleColumns.length + 1}>
                      <EmptyState
                        compact
                        icon={table.emptyIcon}
                        title={table.emptyMessage ?? 'No results found'}
                        description={
                          deferredSearch || (filters as FilterRule[]).length > 0
                            ? 'Try adjusting your search or filters'
                            : undefined
                        }
                      />
                    </TableEmpty>
                  ) : (
                    rows.map((row) => (
                      <SortableRow key={(row as any).id} row={row} columns={visibleColumns} />
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
                {headerColumns.map((col) => (
                  <TableHead key={col.key} className={col.headerClassName}>
                    {col.label}
                  </TableHead>
                ))}
              </tr>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableEmpty colSpan={visibleColumns.length}>Loading...</TableEmpty>
              ) : rows.length === 0 ? (
                <TableEmpty colSpan={visibleColumns.length}>
                  <EmptyState
                    compact
                    icon={table.emptyIcon}
                    title={table.emptyMessage ?? 'No results found'}
                    description={
                      deferredSearch || (filters as FilterRule[]).length > 0
                        ? 'Try adjusting your search or filters'
                        : undefined
                    }
                  />
                </TableEmpty>
              ) : (
                rows.map((row, i) => (
                  <TableRow key={(row as any).id ?? i}>
                    {visibleColumns.map((col) => (
                      <TableCell key={col.key} className={col.className}>
                        {col.render ? col.render(row) : String((row as any)[col.key] ?? '—')}
                      </TableCell>
                    ))}
                  </TableRow>
                ))
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
}: {
  row: T
  columns: ColumnDef[]
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
      <TableCell className="w-8 touch-none p-0">
        <DragHandle attributes={attributes} listeners={listeners} />
      </TableCell>
      {columns.map((col) => (
        <TableCell key={col.key} className={col.className}>
          {col.render ? col.render(row) : String((row as any)[col.key] ?? '—')}
        </TableCell>
      ))}
    </tr>
  )
}

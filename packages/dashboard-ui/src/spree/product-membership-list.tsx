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
import { type ReactNode, useEffect, useMemo, useState } from 'react'
import { cn } from '../lib/utils'
import { Badge } from '../ui/badge'
import { Button } from '../ui/button'
import { Checkbox } from '../ui/checkbox'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../ui/data-table'
import { Pagination, type PaginationMeta } from '../ui/pagination'
import { Thumbnail } from '../ui/thumbnail'
import { DragHandle } from './drag-handle'
import { Undo2Icon, XIcon } from './icons'
import { SearchInput } from './search-input'

/** One product row in a membership list. */
export interface ProductMembershipRow {
  id: string
  name?: string | null
  thumbnailUrl?: string | null
  /**
   * Deferred-editing state: `added` rows are staged locally and not yet
   * persisted (badged, not draggable); `removed` rows are struck through and
   * their remove button becomes a restore.
   */
  pending?: 'added' | 'removed'
}

/** All user-visible copy, so the component stays free of locale namespaces. */
export interface ProductMembershipListLabels {
  filterPlaceholder: string
  clearFilter: string
  noMatches: string
  empty: string
  loading: string
  columnProduct: string
  selectAll: string
  selectRow: string
  remove: string
  /** Required when any row can be `pending: 'removed'`. */
  restore?: string
  /** Badge on `pending: 'added'` rows. */
  pendingAddedBadge?: string
}

export interface ProductMembershipListProps {
  rows: ProductMembershipRow[]
  labels: ProductMembershipListLabels
  loading?: boolean
  meta?: PaginationMeta | null
  onPageChange?: (page: number) => void
  /** Hides checkboxes, drag handles and remove buttons. */
  readOnly?: boolean
  /** Controlled selection — the host renders the bulk actions that consume it. */
  selected?: string[]
  onSelectedChange?: (ids: string[]) => void
  onRemove?: (id: string) => void
  onRestore?: (id: string) => void
  /** Enables drag-to-reorder. Filtered views never reorder. */
  reorderable?: boolean
  /**
   * Persist a drag. `position` is the 0-based index across the whole set
   * (page offset already applied). A rejected promise rolls the row back.
   */
  onReorder?: (id: string, position: number) => Promise<unknown> | undefined
  /** Row title cell — pass a link to the product page; defaults to plain text. */
  renderTitle?: (row: ProductMembershipRow) => ReactNode
  /**
   * Extra columns between the product name and the remove button, for a
   * parent whose membership carries data of its own — a catalog's quantity
   * terms, say. Headers and cells are passed separately so the host stays in
   * charge of what a row means to it; both must return the same number of
   * cells or the table misaligns.
   */
  extraColumns?: {
    headers: ReactNode
    renderCells: (row: ProductMembershipRow) => ReactNode
  }
}

/**
 * The shared membership table for "products in a grouping" panels —
 * categories, collections, catalogs, price lists. Headless: rows, selection
 * and every mutation come through props; the host owns data fetching, the
 * picker, confirms and save semantics (immediate writes or form state).
 *
 * Renders the client-side quick filter, the selectable rows with thumbnails,
 * optional drag-to-reorder with optimistic rollback, and pagination.
 */
export function ProductMembershipList({
  rows,
  labels,
  loading = false,
  meta,
  onPageChange,
  readOnly = false,
  selected = [],
  onSelectedChange,
  onRemove,
  onRestore,
  reorderable = false,
  onReorder,
  renderTitle,
  extraColumns,
}: ProductMembershipListProps) {
  const [query, setQuery] = useState('')

  // Local order mirrors the incoming rows so a drag re-renders instantly;
  // a resolved onReorder re-syncs through the next rows prop.
  const [order, setOrder] = useState<ProductMembershipRow[]>(rows)
  useEffect(() => {
    setOrder(rows)
  }, [rows])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const ids = useMemo(() => order.map((row) => row.id), [order])

  // Client-side quick filter over the current page. While a filter is active,
  // drag-reorder is disabled — reordering a filtered subset would compute
  // positions against the wrong neighbours.
  const trimmedQuery = query.trim().toLowerCase()
  const filtering = trimmedQuery.length > 0
  const visible = useMemo(
    () =>
      filtering
        ? order.filter((row) => (row.name ?? '').toLowerCase().includes(trimmedQuery))
        : order,
    [order, filtering, trimmedQuery],
  )

  // Rows a checkbox makes sense for — pending removals restore instead.
  const selectableIds = useMemo(
    () => visible.filter((row) => row.pending !== 'removed').map((row) => row.id),
    [visible],
  )
  const selectedSet = useMemo(() => new Set(selected), [selected])
  const allSelected = selectableIds.length > 0 && selectableIds.every((id) => selectedSet.has(id))

  function toggleSelected(id: string) {
    if (!onSelectedChange) return
    onSelectedChange(
      selectedSet.has(id) ? selected.filter((existing) => existing !== id) : [...selected, id],
    )
  }

  // Operate only on the currently-visible (filtered) rows so "select all"
  // never pulls in hidden products a later bulk action would touch unseen.
  function toggleAll() {
    if (!onSelectedChange) return
    if (allSelected) {
      const visibleSet = new Set(selectableIds)
      onSelectedChange(selected.filter((id) => !visibleSet.has(id)))
    } else {
      onSelectedChange([...new Set([...selected, ...selectableIds])])
    }
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id || !onReorder) return
    const from = order.findIndex((row) => row.id === active.id)
    const to = order.findIndex((row) => row.id === over.id)
    if (from === -1 || to === -1) return
    const previousOrder = order
    setOrder(arrayMove(order, from, to)) // optimistic
    // `to` is an index within the current page; the caller wants a 0-based
    // index across the whole grouping. `meta.from` is 1-based.
    const result = onReorder(String(active.id), (meta?.from ?? 1) - 1 + to)
    Promise.resolve(result).catch(() => setOrder(previousOrder))
  }

  const curatable = !readOnly

  if (loading) {
    return <p className="p-6 text-muted-foreground text-sm">{labels.loading}</p>
  }

  if (order.length === 0) {
    return <p className="p-6 text-muted-foreground text-sm">{labels.empty}</p>
  }

  return (
    <>
      <div className="border-border-subtle border-b p-3">
        <SearchInput
          value={query}
          onValueChange={setQuery}
          onKeyDown={(e) => e.key === 'Enter' && e.preventDefault()}
          placeholder={labels.filterPlaceholder}
          clearLabel={labels.clearFilter}
        />
      </div>
      {visible.length === 0 ? (
        <p className="p-6 text-muted-foreground text-sm">{labels.noMatches}</p>
      ) : (
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <Table>
            <TableHeader>
              <TableRow>
                {curatable && (
                  <TableHead className="w-10">
                    <Checkbox
                      checked={allSelected}
                      onCheckedChange={toggleAll}
                      aria-label={labels.selectAll}
                    />
                  </TableHead>
                )}
                {reorderable && <TableHead className="w-8" />}
                <TableHead>{labels.columnProduct}</TableHead>
                {extraColumns?.headers}
                <TableHead className="w-10" />
              </TableRow>
            </TableHeader>
            <SortableContext items={ids} strategy={verticalListSortingStrategy}>
              {/* No border-t: TableHead draws the rule as an inset shadow,
                  and a border alongside it stacks into a 2px line. */}
              <TableBody>
                {visible.map((row) => (
                  <MembershipRow
                    key={row.id}
                    row={row}
                    curatable={curatable}
                    // Reorder only makes sense over the full page of settled
                    // rows; staged rows have no position yet.
                    reorderable={reorderable && curatable && !filtering && !row.pending}
                    showDragColumn={reorderable}
                    selected={selectedSet.has(row.id)}
                    onToggleSelected={() => toggleSelected(row.id)}
                    onRemove={onRemove ? () => onRemove(row.id) : undefined}
                    onRestore={onRestore ? () => onRestore(row.id) : undefined}
                    labels={labels}
                    renderTitle={renderTitle}
                    extraCells={extraColumns?.renderCells(row)}
                  />
                ))}
              </TableBody>
            </SortableContext>
          </Table>
        </DndContext>
      )}
      {/* Pagination brings its own top border + padding. */}
      {meta && onPageChange && <Pagination meta={meta} onPageChange={onPageChange} />}
    </>
  )
}

function MembershipRow({
  row,
  curatable,
  reorderable,
  showDragColumn,
  selected,
  onToggleSelected,
  onRemove,
  onRestore,
  labels,
  renderTitle,
  extraCells,
}: {
  row: ProductMembershipRow
  curatable: boolean
  reorderable: boolean
  showDragColumn: boolean
  selected: boolean
  onToggleSelected: () => void
  onRemove?: () => void
  onRestore?: () => void
  labels: ProductMembershipListLabels
  renderTitle?: (row: ProductMembershipRow) => ReactNode
  extraCells?: ReactNode
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: row.id,
    disabled: !reorderable,
  })

  const removed = row.pending === 'removed'
  const added = row.pending === 'added'

  return (
    <tr
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      // Mirror <TableRow> styling — a plain <tr> is required so dnd-kit's
      // setNodeRef attaches (TableRow doesn't forward refs).
      className={cn(
        'group/row last:*:border-b-0 hover:bg-accent/60',
        selected && 'bg-accent/60 hover:bg-accent',
        isDragging && 'relative z-10 opacity-70',
        removed && 'opacity-60',
      )}
    >
      {curatable && (
        <TableCell>
          {!removed && (
            <Checkbox
              checked={selected}
              onCheckedChange={onToggleSelected}
              aria-label={labels.selectRow}
            />
          )}
        </TableCell>
      )}
      {showDragColumn && (
        <TableCell className="pr-0">
          {reorderable && <DragHandle attributes={attributes} listeners={listeners} />}
        </TableCell>
      )}
      <TableCell>
        <span className={cn('flex items-center gap-3', removed && 'line-through')}>
          <Thumbnail src={row.thumbnailUrl} size="sm" />
          {renderTitle ? renderTitle(row) : <span className="truncate text-sm">{row.name}</span>}
          {added && labels.pendingAddedBadge && (
            <Badge variant="secondary">{labels.pendingAddedBadge}</Badge>
          )}
        </span>
      </TableCell>
      {extraCells}
      <TableCell className="text-right">
        {curatable &&
          (removed
            ? onRestore && (
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  onClick={onRestore}
                  aria-label={labels.restore ?? labels.remove}
                >
                  <Undo2Icon className="size-4" />
                </Button>
              )
            : onRemove && (
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  onClick={onRemove}
                  aria-label={labels.remove}
                >
                  <XIcon className="size-4" />
                </Button>
              ))}
      </TableCell>
    </tr>
  )
}

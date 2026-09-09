import {
  flexRender,
  getCoreRowModel,
  type Row,
  type Table,
  type TableOptions,
  useReactTable,
} from '@tanstack/react-table'
import { useCallback, useMemo, useRef, useState } from 'react'
import { cn } from '../../lib/utils'
import { coordsInRect, DataGridContext, type DataGridContextValue } from './context'
import { FillHandle } from './fill-handle'
import type { CellCoords, CellKey, CellRegistration, RenderSectionHeader } from './types'
import { cellKey } from './types'
import { useDataGridKeyboard } from './use-data-grid-keyboard'

interface DataGridProps<T> {
  rows: T[]
  columns: TableOptions<T>['columns']
  getRowId: (row: T) => string
  /** Optional grouping. Return a node spanning all columns to render this row
   *  as a (non-editable) section header. Return null to render the row as
   *  normal editable cells. */
  renderSectionHeader?: RenderSectionHeader<T>
  /** Optional className on the outer table. */
  className?: string
  /** Optional caption-row aria-label etc. */
  'aria-label'?: string
  /**
   * Whether the grid scrolls inside its own box.
   *
   * `true` for a grid too wide or tall for where it sits — the bulk variant
   * editor in its dialog, which has columns well past any viewport. `false`
   * when the container already handles it, or when the grid is sized to fit:
   * the fill handle straddles the selection's bottom-right corner and hangs a
   * few pixels past the table, which a scroll container counts as content, so
   * selecting an edge cell raises scrollbars on a grid that fits.
   */
  scrollable?: boolean
}

export function DataGrid<T>({
  rows,
  columns,
  getRowId,
  renderSectionHeader,
  className,
  'aria-label': ariaLabel,
  scrollable = false,
}: DataGridProps<T>) {
  const table = useReactTable<T>({
    data: rows,
    columns,
    getRowId,
    getCoreRowModel: getCoreRowModel(),
  })

  return (
    <DataGridShell
      table={table}
      renderSectionHeader={renderSectionHeader}
      className={className}
      ariaLabel={ariaLabel}
      scrollable={scrollable}
    />
  )
}

function DataGridShell<T>({
  table,
  renderSectionHeader,
  className,
  ariaLabel,
  scrollable,
}: {
  table: Table<T>
  renderSectionHeader?: RenderSectionHeader<T>
  className?: string
  ariaLabel?: string
  scrollable?: boolean
}) {
  const gridRef = useRef<HTMLTableElement | null>(null)
  const cellsRef = useRef<Map<CellKey, CellRegistration>>(new Map())
  const [bounds, setBounds] = useState<{ maxRow: number; maxCol: number }>({ maxRow: 0, maxCol: 0 })
  const [anchor, setAnchor] = useState<CellCoords | null>(null)
  // Read by the blur handler, which fires from a DOM event and would
  // otherwise close over a stale anchor.
  const anchorRef = useRef<CellCoords | null>(null)
  anchorRef.current = anchor
  const [extent, setExtent] = useState<CellCoords | null>(null)
  const [editing, setEditing] = useState<CellCoords | null>(null)

  const recomputeBounds = useCallback(() => {
    let maxRow = 0
    let maxCol = 0
    for (const reg of cellsRef.current.values()) {
      if (reg.coords.row > maxRow) maxRow = reg.coords.row
      if (reg.coords.col > maxCol) maxCol = reg.coords.col
    }
    setBounds((prev) =>
      prev.maxRow === maxRow && prev.maxCol === maxCol ? prev : { maxRow, maxCol },
    )
  }, [])

  // A cell the grid wants focused that has not registered yet. Cells register
  // in an effect, so a commit that ADDS a row — a spreadsheet whose last line
  // is a blank waiting to be filled — asks for a cell that does not exist
  // until the next render. Without this the focus is dropped on the floor and
  // the arrow keys stop responding, since nothing holds the selection
  // (docs/plans/6.0-volume-pricing.md).
  const pendingFocusRef = useRef<CellCoords | null>(null)

  const focusCell = useCallback((coords: CellCoords) => {
    const target = cellsRef.current.get(cellKey(coords))
    // Focus now if the cell is already there, but ask again once the render
    // this commit triggers has settled. Committing an edit re-renders the
    // row, and React replaces the input we just focused — inside a dialog
    // the browser then falls back to the dialog itself, which leaves nothing
    // holding the selection and the arrow keys dead until the merchant
    // clicks a cell (docs/plans/6.0-volume-pricing.md).
    target?.focus()
    pendingFocusRef.current = coords
    requestAnimationFrame(() => {
      const pending = pendingFocusRef.current
      if (!pending || cellKey(pending) !== cellKey(coords)) return
      pendingFocusRef.current = null
      const cell = cellsRef.current.get(cellKey(coords))
      if (cell) {
        cell.focus()
        return
      }
      // No cell to focus — keep the keyboard in the grid rather than letting
      // it fall back to whatever contains it.
      gridRef.current?.focus()
    })
  }, [])

  const registerCell = useCallback(
    (reg: CellRegistration) => {
      const key = cellKey(reg.coords)
      cellsRef.current.set(key, reg)
      recomputeBounds()

      // The cell someone asked for has arrived — give it the focus it was
      // promised, after this render commits.
      const pending = pendingFocusRef.current
      if (pending && cellKey(pending) === key) {
        pendingFocusRef.current = null
        queueMicrotask(() => cellsRef.current.get(key)?.focus())
      }

      return () => {
        cellsRef.current.delete(key)
        recomputeBounds()
      }
    },
    [recomputeBounds],
  )

  const isSelected = useCallback(
    (coords: CellCoords) => coordsInRect(coords, anchor, extent),
    [anchor, extent],
  )

  const selectedCells = useCallback((): CellRegistration[] => {
    if (!anchor || !extent) return []
    const out: CellRegistration[] = []
    for (const reg of cellsRef.current.values()) {
      if (coordsInRect(reg.coords, anchor, extent)) out.push(reg)
    }
    return out
  }, [anchor, extent])

  const ctx: DataGridContextValue = useMemo(
    () => ({
      cells: cellsRef.current,
      bounds,
      anchor,
      extent,
      editing,
      setAnchor,
      setExtent,
      setEditing,
      registerCell,
      focusCell,
      isSelected,
      selectedCells,
    }),
    [bounds, anchor, extent, editing, registerCell, focusCell, isSelected, selectedCells],
  )

  return (
    <DataGridContext.Provider value={ctx}>
      <DataGridKeyboardMount gridRef={gridRef} />
      {/* Scrolls sideways rather than clipping: a grid wide enough to need it
          (the bulk variant editor sets a min-width well past any viewport) had
          its right-hand columns cut off with no way to reach them, because the
          `overflow-hidden` that used to clip this wrapper also beat the
          caller's own scroll container. Nothing rounds the corners now — the
          table's own cell borders draw its edges.

          `max-h-full` is what keeps the sticky header working. Declaring one
          overflow axis makes the other a scroll container too whatever it is
          declared as, so this div scrolls vertically whether or not we ask it
          to — and an unbounded one grows to its full content height, which
          leaves `position: sticky` with nothing to stick within. Bounding it
          to the caller's height gives the header a viewport again, and a
          caller that imposes no height (a grid that scrolls with the page)
          still resolves to no constraint.

          All of it is behind `scrollable`, because a scroll container is not
          free: `position: absolute` takes the fill handle out of layout flow
          but NOT out of a scroller's scrollable overflow, and the handle
          straddles the selection's bottom-right corner. On a cell at the
          grid's edge it therefore hangs a few pixels past the table and the
          container grows to contain it — so selecting an edge cell raised
          scrollbars on a grid that fits its card. A grid that does not need
          to scroll should not be a scroll container. */}
      <div className={cn('relative', scrollable && 'themed-scrollbar max-h-full overflow-auto')}>
        <table
          ref={gridRef}
          // Focusable so the grid itself can hold the keyboard when a cell's
          // input goes away. Committing an edit re-renders the row and React
          // replaces that input; inside a dialog the focus trap then pulls
          // focus to the dialog, which is outside the grid, and every arrow
          // key after it lands on nothing (docs/plans/6.0-volume-pricing.md).
          tabIndex={-1}
          className={cn(
            'w-full border-collapse text-sm outline-none [&_td]:border [&_th]:border [&_td]:border-border [&_th]:border-border',
            // Internal rules only. `border` on every cell also draws the grid's
            // outer edge — `border-collapse` merges neighbours, so the outermost
            // cells' outer sides become the table's own frame, doubling the
            // card's border a pixel away from it. These grids are always inside
            // a container that draws that edge already.
            '[&_tr>*:first-child]:border-l-0 [&_tr>*:last-child]:border-r-0 [&_thead_tr:first-child>*]:border-t-0 [&_tbody_tr:last-child>*]:border-b-0',
            // The header draws its bottom rule as an inset shadow (see the
            // `<th>` below), so its border would stack into a second line.
            '[&_thead_th]:border-b-0',
            className,
          )}
          aria-label={ariaLabel}
          onBlurCapture={(e) => {
            // A cell unmounting mid-commit is not the merchant leaving the
            // grid: `relatedTarget` is null there, and the dialog's focus
            // trap then claims the focus a frame later. Take it back on the
            // spot and keep the selection, rather than racing that trap on a
            // timer (docs/plans/6.0-volume-pricing.md).
            const next = e.relatedTarget as Node | null
            if (next && gridRef.current?.contains(next)) return
            // Two hops the merchant did not ask for, both caused by a cell
            // being replaced mid-commit: the browser dropping focus
            // (`relatedTarget` null), and the surrounding dialog's focus trap
            // then claiming it. Neither means the grid was left, so keep the
            // selection and take the keyboard back.
            const trapped =
              next === null ||
              (next instanceof Element &&
                next.closest('[role="dialog"]')?.contains(gridRef.current ?? null) === true)
            if (trapped) {
              // After this event resolves, or the trap that prompted it wins.
              if (anchorRef.current) {
                queueMicrotask(() => gridRef.current?.focus({ preventScroll: true }))
              }
              return
            }
            // Focus moved somewhere real outside the grid — the merchant is
            // done here, so drop the selection and let a fresh focus-in start
            // clean.
            setAnchor(null)
            setExtent(null)
            setEditing(null)
          }}
        >
          {/* The fill is on the cells, not the row: under `border-collapse` a
              background on `<thead>` or `<tr>` paints unreliably, and it has to
              be opaque — this row pins over the grid's own scrolling content,
              so a translucent one (it was `bg-muted/60`) lets the rows behind
              it read straight through the column labels. */}
          <thead className="sticky top-0 z-10 text-xs text-muted-foreground">
            {table.getHeaderGroups().map((group) => (
              <tr key={group.id}>
                {group.headers.map((header) => (
                  <th
                    key={header.id}
                    // The bottom rule is an inset shadow, not the cell's own
                    // border: under `border-collapse` the collapsed borders
                    // belong to the table, so they scroll away with it and a
                    // pinned header ends up with rows sliding flush against its
                    // labels. A shadow belongs to the cell and pins with it.
                    //
                    // The table-level classes zero this cell's own top and
                    // bottom borders: a border sits outside the padding box and
                    // the shadow inside, so leaving both draws two rules at rest.
                    className="h-8 bg-muted px-3 text-left font-medium shadow-[inset_0_-1px_0_0_var(--border)]"
                  >
                    {header.isPlaceholder
                      ? null
                      : flexRender(header.column.columnDef.header, header.getContext())}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map((row) => (
              <DataGridRow
                key={row.id}
                row={row}
                renderSectionHeader={renderSectionHeader}
                columnCount={table.getAllColumns().length}
              />
            ))}
          </tbody>
        </table>
        <FillHandle gridRef={gridRef} />
      </div>
    </DataGridContext.Provider>
  )
}

function DataGridRow<T>({
  row,
  renderSectionHeader,
  columnCount,
}: {
  row: Row<T>
  renderSectionHeader?: RenderSectionHeader<T>
  columnCount: number
}) {
  const headerContent = renderSectionHeader?.(row.original)
  if (headerContent) {
    return (
      <tr>
        <td colSpan={columnCount} className="bg-muted/60 px-3 py-2 text-sm">
          {headerContent}
        </td>
      </tr>
    )
  }
  return (
    <tr>
      {row.getVisibleCells().map((cell) => (
        <td key={cell.id} className="h-9 p-0 align-middle">
          {flexRender(cell.column.columnDef.cell, cell.getContext())}
        </td>
      ))}
    </tr>
  )
}

function DataGridKeyboardMount({ gridRef }: { gridRef: React.RefObject<HTMLElement | null> }) {
  useDataGridKeyboard(gridRef)
  return null
}

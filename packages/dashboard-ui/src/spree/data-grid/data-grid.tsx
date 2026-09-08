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
}

export function DataGrid<T>({
  rows,
  columns,
  getRowId,
  renderSectionHeader,
  className,
  'aria-label': ariaLabel,
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
    />
  )
}

function DataGridShell<T>({
  table,
  renderSectionHeader,
  className,
  ariaLabel,
}: {
  table: Table<T>
  renderSectionHeader?: RenderSectionHeader<T>
  className?: string
  ariaLabel?: string
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
          still resolves to no constraint. */}
      <div className="relative max-h-full overflow-auto">
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
          <thead className="sticky top-0 z-10 bg-muted/60 text-xs text-muted-foreground">
            {table.getHeaderGroups().map((group) => (
              <tr key={group.id}>
                {group.headers.map((header) => (
                  <th key={header.id} className="h-8 px-3 text-left font-medium">
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

import {
  flexRender,
  getCoreRowModel,
  type Row,
  type Table,
  type TableOptions,
  useReactTable,
} from '@tanstack/react-table'
import { useCallback, useMemo, useRef, useState } from 'react'
import { cn } from '@/lib/utils'
import { coordsInRect, DataGridContext, type DataGridContextValue } from './context'
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

  const registerCell = useCallback(
    (reg: CellRegistration) => {
      const key = cellKey(reg.coords)
      cellsRef.current.set(key, reg)
      recomputeBounds()
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
      isSelected,
      selectedCells,
    }),
    [bounds, anchor, extent, editing, registerCell, isSelected, selectedCells],
  )

  return (
    <DataGridContext.Provider value={ctx}>
      <DataGridKeyboardMount gridRef={gridRef} />
      <div className="overflow-hidden rounded-md">
        <table
          ref={gridRef}
          className={cn(
            'w-full border-collapse text-sm [&_td]:border [&_th]:border [&_td]:border-border [&_th]:border-border',
            className,
          )}
          aria-label={ariaLabel}
          onBlurCapture={(e) => {
            // If focus leaves the grid entirely, drop the selection so a
            // fresh focus-in starts clean.
            const next = e.relatedTarget as Node | null
            if (next && gridRef.current?.contains(next)) return
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

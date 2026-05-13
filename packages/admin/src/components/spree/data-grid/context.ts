import { createContext, useContext } from 'react'
import type { CellCoords, CellKey, CellRegistration, GridMode } from './types'

export interface DataGridContextValue {
  /** Stable map of `${row}.${col}` → registration. Mutated imperatively by
   *  cells in their mount effect so we don't churn React state on every
   *  render. Consumers should iterate via `eachCell()` rather than peeking
   *  at the Map directly. */
  cells: Map<CellKey, CellRegistration>

  /** Bounds, recomputed when cells register/unregister. */
  bounds: { maxRow: number; maxCol: number }

  /** Selection anchor (origin of a Shift+Arrow extension) and extent (current
   *  far corner). When equal, only one cell is selected. Null means no
   *  selection at all. */
  anchor: CellCoords | null
  extent: CellCoords | null

  /** Currently editing cell. When set, keyboard nav shortcuts are routed
   *  through the cell instead of the grid. */
  editing: CellCoords | null

  /** Dispatchers — components react via subscribed selectors below. */
  setAnchor: (coords: CellCoords | null) => void
  setExtent: (coords: CellCoords | null) => void
  setEditing: (coords: CellCoords | null) => void

  /** Register/unregister a cell. Returns a cleanup. */
  registerCell: (reg: CellRegistration) => () => void

  /** Snapshot helpers used by the keyboard hook. */
  isSelected: (coords: CellCoords) => boolean
  selectedCells: () => CellRegistration[]
}

export const DataGridContext = createContext<DataGridContextValue | null>(null)

export function useDataGridContext(): DataGridContextValue {
  const ctx = useContext(DataGridContext)
  if (!ctx) {
    throw new Error('Data grid cells must be rendered inside <DataGrid>.')
  }
  return ctx
}

/** Inclusive rectangle test. */
export function coordsInRect(c: CellCoords, a: CellCoords | null, b: CellCoords | null): boolean {
  if (!a || !b) return false
  const minRow = Math.min(a.row, b.row)
  const maxRow = Math.max(a.row, b.row)
  const minCol = Math.min(a.col, b.col)
  const maxCol = Math.max(a.col, b.col)
  return c.row >= minRow && c.row <= maxRow && c.col >= minCol && c.col <= maxCol
}

export function modeFor(editing: CellCoords | null, coords: CellCoords): GridMode {
  return editing && editing.row === coords.row && editing.col === coords.col ? 'edit' : 'select'
}

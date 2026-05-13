import type { ReactNode } from 'react'

/** Cell coords used for keyboard navigation and selection.
 *  `row` is a flat row index across the rendered table (after section
 *  headers are inserted); `col` is the column index in the editable order. */
export interface CellCoords {
  row: number
  col: number
}

export type CellKey = `${number}.${number}`

export function cellKey(coords: CellCoords): CellKey {
  return `${coords.row}.${coords.col}`
}

export type GridMode = 'select' | 'edit'

export interface CellRegistration {
  coords: CellCoords
  /** Imperatively focus the cell's interactive element. */
  focus: () => void
  /** Read the current display value (for copy / fill-down). */
  read: () => string
  /** Write a new value (for paste / fill-down / clear). */
  write: (value: string) => void
  /** Whether this cell accepts a write — Switch cells, for example, only
   *  accept "true" / "false" / "" so we can no-op on non-boolean pastes. */
  canWrite: (value: string) => boolean
}

/** Public render-prop API for grouped rows (e.g. "Variant: Small / Navy"). */
export type RenderSectionHeader<T> = (row: T) => ReactNode | null

import { useHotkey } from '@tanstack/react-hotkeys'
import type { RefObject } from 'react'
import { useDataGridContext } from './context'
import type { CellCoords } from './types'

/** Mounts grid-wide keyboard bindings scoped to a container ref. */
export function useDataGridKeyboard(gridRef: RefObject<HTMLElement | null>) {
  const ctx = useDataGridContext()
  const target = gridRef

  function focusCoords(coords: CellCoords) {
    const cell = ctx.cells.get(`${coords.row}.${coords.col}`)
    cell?.focus()
  }

  function navigate(dx: number, dy: number) {
    const from = ctx.anchor
    if (!from) return
    // Clamp inside the grid, no wrap-around.
    let row = from.row + dy
    let col = from.col + dx
    row = Math.max(0, Math.min(ctx.bounds.maxRow, row))
    col = Math.max(0, Math.min(ctx.bounds.maxCol, col))
    // If the target slot has no registered cell (e.g. a sparse row where the
    // column index doesn't render), find the nearest existing cell in the
    // direction of travel. Falls back to the original if nothing is reachable.
    const next = findExistingCoords({ row, col }, dx, dy)
    if (!next) return
    ctx.setAnchor(next)
    ctx.setExtent(next)
    ctx.setEditing(null)
    focusCoords(next)
  }

  function extendSelection(dx: number, dy: number) {
    const from = ctx.extent ?? ctx.anchor
    if (!from) return
    let row = from.row + dy
    let col = from.col + dx
    row = Math.max(0, Math.min(ctx.bounds.maxRow, row))
    col = Math.max(0, Math.min(ctx.bounds.maxCol, col))
    const next = findExistingCoords({ row, col }, dx, dy)
    if (!next) return
    ctx.setExtent(next)
    focusCoords(next)
  }

  function findExistingCoords(start: CellCoords, dx: number, dy: number): CellCoords | null {
    if (ctx.cells.has(`${start.row}.${start.col}`)) return start
    // Step in the direction of travel until we find a registered cell or
    // run out of grid. Bounded by maxRow*maxCol steps.
    let row = start.row
    let col = start.col
    for (let i = 0; i < (ctx.bounds.maxRow + 1) * (ctx.bounds.maxCol + 1); i++) {
      row += dy === 0 ? 0 : dy
      col += dx === 0 ? 0 : dx
      // If we're walking pure-row, also step columns to find sparse hits.
      if (dx === 0 && dy === 0) return null
      if (row < 0 || col < 0 || row > ctx.bounds.maxRow || col > ctx.bounds.maxCol) return null
      if (ctx.cells.has(`${row}.${col}`)) return { row, col }
    }
    return null
  }

  // Selection-mode navigation. Edit-mode is handled inside the cell itself
  // (Enter / Esc / Tab there route to the grid via callbacks).
  useHotkey('ArrowUp', () => navigate(0, -1), {
    target,
    ignoreInputs: false,
    enabled: !ctx.editing,
  })
  useHotkey('ArrowDown', () => navigate(0, 1), {
    target,
    ignoreInputs: false,
    enabled: !ctx.editing,
  })
  useHotkey('ArrowLeft', () => navigate(-1, 0), {
    target,
    ignoreInputs: false,
    enabled: !ctx.editing,
  })
  useHotkey('ArrowRight', () => navigate(1, 0), {
    target,
    ignoreInputs: false,
    enabled: !ctx.editing,
  })

  useHotkey('Shift+ArrowUp', () => extendSelection(0, -1), {
    target,
    ignoreInputs: false,
    enabled: !ctx.editing,
  })
  useHotkey('Shift+ArrowDown', () => extendSelection(0, 1), {
    target,
    ignoreInputs: false,
    enabled: !ctx.editing,
  })
  useHotkey('Shift+ArrowLeft', () => extendSelection(-1, 0), {
    target,
    ignoreInputs: false,
    enabled: !ctx.editing,
  })
  useHotkey('Shift+ArrowRight', () => extendSelection(1, 0), {
    target,
    ignoreInputs: false,
    enabled: !ctx.editing,
  })

  // Tab: navigate within the grid; let the browser handle when at the edge
  // so the user can Tab past the grid into the next form field.
  useHotkey(
    'Tab',
    (event) => {
      const from = ctx.anchor
      if (!from) return
      const atLastCell = from.row === ctx.bounds.maxRow && from.col === ctx.bounds.maxCol
      if (atLastCell) return // let browser focus the next form field
      event.preventDefault()
      navigate(1, 0)
      // If we just walked off the right edge, wrap to the next row.
      const next = ctx.anchor
      if (next && next.row === from.row && next.col === from.col) {
        navigate(-ctx.bounds.maxCol, 1)
      }
    },
    { target, ignoreInputs: false, preventDefault: false, enabled: !ctx.editing },
  )
  useHotkey(
    'Shift+Tab',
    (event) => {
      const from = ctx.anchor
      if (!from) return
      const atFirst = from.row === 0 && from.col === 0
      if (atFirst) return // let browser walk focus backward out of the grid
      event.preventDefault()
      navigate(-1, 0)
    },
    { target, ignoreInputs: false, preventDefault: false, enabled: !ctx.editing },
  )

  // Enter — toggle into edit mode for the focused cell.
  useHotkey(
    'Enter',
    () => {
      if (ctx.anchor) ctx.setEditing(ctx.anchor)
    },
    { target, ignoreInputs: false, enabled: !ctx.editing },
  )

  // Escape — clear selection. (Edit-mode Escape is handled inside the cell
  // since it needs to revert the in-flight value before exiting.)
  useHotkey(
    'Escape',
    () => {
      ctx.setExtent(ctx.anchor)
    },
    { target, ignoreInputs: false, enabled: !ctx.editing },
  )

  // Delete / Backspace — clear all selected cells. Skipped while editing
  // so the user can use these keys to edit text.
  function clearSelected() {
    for (const cell of ctx.selectedCells()) {
      if (cell.canWrite('')) cell.write('')
    }
  }
  useHotkey('Delete', clearSelected, { target, ignoreInputs: false, enabled: !ctx.editing })
  useHotkey('Backspace', clearSelected, { target, ignoreInputs: false, enabled: !ctx.editing })

  // Cmd/Ctrl+D — fill down: take the top-most cell of each selected column
  // and broadcast its value to the rest of that column's selection.
  useHotkey(
    'Mod+D',
    () => {
      const cells = ctx.selectedCells()
      if (cells.length < 2) return
      const byCol = new Map<number, typeof cells>()
      for (const c of cells) {
        const arr = byCol.get(c.coords.col) ?? []
        arr.push(c)
        byCol.set(c.coords.col, arr)
      }
      for (const colCells of byCol.values()) {
        colCells.sort((a, b) => a.coords.row - b.coords.row)
        const source = colCells[0].read()
        for (let i = 1; i < colCells.length; i++) {
          if (colCells[i].canWrite(source)) colCells[i].write(source)
        }
      }
    },
    { target, ignoreInputs: false, enabled: !ctx.editing },
  )

  // Cmd/Ctrl+C — write the selection to the OS clipboard as TSV.
  useHotkey(
    'Mod+C',
    async () => {
      const cells = ctx.selectedCells()
      if (cells.length === 0) return
      const rows = new Map<number, Map<number, string>>()
      let minCol = Infinity
      let maxCol = -Infinity
      for (const c of cells) {
        const row = rows.get(c.coords.row) ?? new Map()
        row.set(c.coords.col, c.read())
        rows.set(c.coords.row, row)
        if (c.coords.col < minCol) minCol = c.coords.col
        if (c.coords.col > maxCol) maxCol = c.coords.col
      }
      const rowKeys = Array.from(rows.keys()).sort((a, b) => a - b)
      const tsv = rowKeys
        .map((r) => {
          const row = rows.get(r)
          const out: string[] = []
          for (let col = minCol; col <= maxCol; col++) {
            out.push(row?.get(col) ?? '')
          }
          return out.join('\t')
        })
        .join('\n')
      try {
        await navigator.clipboard.writeText(tsv)
      } catch {
        // Clipboard write may fail in non-secure contexts or when the page
        // doesn't have focus. Silent — the alternative is a noisy toast on
        // a routine Cmd+C and there's no recovery path here.
      }
    },
    { target, ignoreInputs: false, enabled: !ctx.editing },
  )

  // Cmd/Ctrl+V — broadcast a single clipboard value to all selected cells.
  // Multi-cell TSV paste with row/col pattern matching is deferred.
  useHotkey(
    'Mod+V',
    async () => {
      const cells = ctx.selectedCells()
      if (cells.length === 0) return
      let text = ''
      try {
        text = await navigator.clipboard.readText()
      } catch {
        return
      }
      // First-pass: only use the first line, first column of whatever was on
      // the clipboard. Excel TSV will collapse cleanly to its first cell.
      const value = text.split('\n')[0]?.split('\t')[0] ?? ''
      for (const c of cells) {
        if (c.canWrite(value)) c.write(value)
      }
    },
    { target, ignoreInputs: false, enabled: !ctx.editing },
  )
}

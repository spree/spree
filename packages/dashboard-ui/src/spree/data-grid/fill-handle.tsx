import { useEffect, useState } from 'react'
import { useDataGridContext } from './context'
import type { CellCoords, CellKey } from './types'
import { cellKey } from './types'

/**
 * Excel-style fill handle. Renders a 9×9 square anchored to the
 * bottom-right of the cell that's the current selection's far corner.
 * Pointer-drag from the handle expands the selection rectangle; on
 * release we copy the anchor cell's value into every other cell in
 * the rectangle (skipping cells whose `canWrite` rejects the value).
 *
 * Positioning is absolute over the grid's `<table>`. The handle reads
 * the far-corner cell's bounding rect via `getElement()` (provided by
 * each cell's registration) and the table's own rect, then offsets so
 * the handle sits inside the cell's corner.
 */
export function FillHandle({ gridRef }: { gridRef: React.RefObject<HTMLElement | null> }) {
  const ctx = useDataGridContext()
  const { anchor, extent, cells, editing } = ctx

  // Local drag state — null when idle.
  const [drag, setDrag] = useState<{
    sourceKey: CellKey
    sourceValue: string
    /** The current rect we're previewing as the fill target. */
    preview: { row: number; col: number } | null
  } | null>(null)
  const [tick, setTick] = useState(0)
  // Re-measure on scroll/resize so the handle follows the cell.
  useEffect(() => {
    function bump() {
      setTick((t) => t + 1)
    }
    window.addEventListener('resize', bump)
    window.addEventListener('scroll', bump, true)
    return () => {
      window.removeEventListener('resize', bump)
      window.removeEventListener('scroll', bump, true)
    }
  }, [])

  // Hide the handle while editing or when there's no selection.
  if (!anchor || !extent || editing) return null

  // Far corner of the current selection (the cell whose bottom-right
  // gets the handle). Drag previews use the same anchor as the source.
  const farRow = Math.max(anchor.row, extent.row)
  const farCol = Math.max(anchor.col, extent.col)
  const farReg = cells.get(cellKey({ row: farRow, col: farCol }))
  const farEl = farReg?.getElement?.()
  const gridEl = gridRef.current
  if (!farEl || !gridEl) return null

  // Position relative to the gridEl's positioning context. Use offsetParent
  // math through getBoundingClientRect for portability.
  const farRect = farEl.getBoundingClientRect()
  const gridRect = gridEl.getBoundingClientRect()
  // Sit the handle so its center is exactly on the cell's bottom-right corner.
  const left = farRect.right - gridRect.left - 4
  const top = farRect.bottom - gridRect.top - 4

  function onPointerDown(e: React.PointerEvent<HTMLDivElement>) {
    e.preventDefault()
    e.stopPropagation()
    // Source is always the *anchor* — that's what users instinctively
    // expect to be copied. If they had a multi-cell selection going,
    // we still copy from the anchor (top-left), matching Excel.
    const sourceReg = cells.get(cellKey(anchor!))
    if (!sourceReg) return
    const sourceValue = sourceReg.read()
    setDrag({
      sourceKey: cellKey(anchor!),
      sourceValue,
      preview: { row: farRow, col: farCol },
    })
    // Capture pointer so we keep getting move events even outside the
    // handle div.
    e.currentTarget.setPointerCapture(e.pointerId)
  }

  function onPointerMove(e: React.PointerEvent<HTMLDivElement>) {
    if (!drag) return
    // Hit-test the cell under the pointer.
    const target = document.elementFromPoint(e.clientX, e.clientY)
    if (!target) return
    // Walk up from the hit target looking for a cell with a known
    // coords attribute. We don't tag DOM nodes, so do it by linear scan
    // through the registry — small (<a few hundred cells per grid).
    let hit: CellCoords | null = null
    for (const reg of cells.values()) {
      const el = reg.getElement?.()
      if (el?.contains(target as Node)) {
        hit = reg.coords
        break
      }
    }
    if (!hit) return
    // Constrain to the same column as the source (Excel: fill flows
    // down a column by default). Allow row movement only.
    setDrag({
      ...drag,
      preview: { row: hit.row, col: anchor!.col },
    })
    // Drive the grid's extent so the standard selection highlight
    // matches the preview region.
    ctx.setExtent({ row: hit.row, col: anchor!.col })
  }

  function onPointerUp() {
    if (!drag) return
    const preview = drag.preview
    if (preview) {
      const minRow = Math.min(anchor!.row, preview.row)
      const maxRow = Math.max(anchor!.row, preview.row)
      // Copy into every cell in the column range, skipping the source.
      for (let r = minRow; r <= maxRow; r += 1) {
        if (r === anchor!.row) continue
        const reg = cells.get(cellKey({ row: r, col: anchor!.col }))
        if (!reg) continue
        if (reg.canWrite(drag.sourceValue)) reg.write(drag.sourceValue)
      }
    }
    setDrag(null)
  }

  // The `tick` value forces position re-measurement when the table
  // reflows. Read it once so React doesn't optimize the var away.
  void tick

  return (
    <div
      // biome-ignore lint/a11y/useSemanticElements: this is a drag handle, not actionable on its own
      role="presentation"
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      style={{
        position: 'absolute',
        left,
        top,
        width: 9,
        height: 9,
        zIndex: 20,
        background: 'rgb(59 130 246)',
        border: '1px solid white',
        cursor: 'crosshair',
        boxShadow: '0 0 0 1px rgba(0,0,0,0.1)',
      }}
      aria-hidden
    />
  )
}

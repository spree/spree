import { useEffect, useRef } from 'react'
import { useDataGridContext } from './context'
import type { CellCoords } from './types'

interface CellHandlers {
  focus: () => void
  read: () => string
  write: (value: string) => void
  canWrite: (value: string) => boolean
}

/**
 * Registers a cell with the data grid exactly once per `(row, col)` slot,
 * forwarding read/write/focus through a ref so per-render closure changes
 * don't re-trigger registration. Without this, every Controller-driven
 * value change would unregister + re-register the cell, which (a) churns
 * the bounds calculation and (b) lands us in setState-during-render loops
 * when the registration effect tries to update grid state.
 *
 * Also reads `registerCell` from the context via a ref so the effect's deps
 * stay limited to coords — the context object itself changes identity on
 * every selection-state update, but `registerCell` is stable beneath it.
 */
export function useStableCellRegistration(coords: CellCoords, handlers: CellHandlers) {
  const ctx = useDataGridContext()
  const handlersRef = useRef(handlers)
  handlersRef.current = handlers
  const registerRef = useRef(ctx.registerCell)
  registerRef.current = ctx.registerCell
  // Destructure to primitives so the effect can list them as deps without
  // pulling in the unstable `coords` object reference from the caller.
  const { row, col } = coords

  useEffect(() => {
    return registerRef.current({
      coords: { row, col },
      focus: () => handlersRef.current.focus(),
      read: () => handlersRef.current.read(),
      write: (v) => handlersRef.current.write(v),
      canWrite: (v) => handlersRef.current.canWrite(v),
    })
  }, [row, col])
}

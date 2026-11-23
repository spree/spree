import { useSyncExternalStore } from 'react'

export type TableDensity = 'comfortable' | 'compact'

const STORAGE_KEY = 'spree-admin-table-density'
const listeners = new Set<() => void>()

function read(): TableDensity {
  try {
    return window.localStorage.getItem(STORAGE_KEY) === 'compact' ? 'compact' : 'comfortable'
  } catch {
    return 'comfortable'
  }
}

// Tables read the density from <html>, so every table on every page follows
// one setting without each list threading a prop through.
function apply(density: TableDensity) {
  if (typeof document === 'undefined') return
  if (density === 'compact') document.documentElement.dataset.tableDensity = 'compact'
  else delete document.documentElement.dataset.tableDensity
}

if (typeof window !== 'undefined') apply(read())

function setTableDensity(density: TableDensity) {
  try {
    if (density === 'compact') window.localStorage.setItem(STORAGE_KEY, density)
    else window.localStorage.removeItem(STORAGE_KEY)
  } catch {
    // Storage blocked: the choice lasts until the page reloads.
  }
  apply(density)
  for (const listener of listeners) listener()
}

function subscribe(listener: () => void) {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

/** The signed-in browser's row density for every resource table. */
export function useTableDensity(): [TableDensity, (density: TableDensity) => void] {
  const density = useSyncExternalStore(
    subscribe,
    () => (document.documentElement.dataset.tableDensity === 'compact' ? 'compact' : 'comfortable'),
    () => 'comfortable' as const,
  )
  return [density, setTableDensity]
}

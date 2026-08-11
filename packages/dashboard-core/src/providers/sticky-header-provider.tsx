import { useScrolled } from '@spree/dashboard-ui'
import { createContext, type ReactNode, useContext, useEffect, useMemo, useState } from 'react'

interface StickyHeaderContextValue {
  /** True while a `PageHeader` is mounted on the current page. */
  hasPageHeader: boolean
  /**
   * True once the user has scrolled far enough for the TopBar to give up its
   * place to the PageHeader. Both headers read this single value so they move
   * as one — deriving it separately in each is what let them desync.
   */
  collapsed: boolean
  /** Registers a mounted `PageHeader`; returns the deregistration callback. */
  registerPageHeader: () => () => void
}

const StickyHeaderContext = createContext<StickyHeaderContextValue | null>(null)

// Engage only once the page has scrolled by more than the TopBar's own height,
// and disengage well before that. Without the gap, a slow scroll around a
// single boundary toggles repeatedly and both headers judder.
const COLLAPSE_AT = 64
const RELEASE_AT = 8

/**
 * Coordinates the two stacked sticky bars — the `TopBar` (search, store
 * switcher, account) and a page's `PageHeader` (title, badges, Save).
 *
 * Only one of them needs to stay on screen while the user scrolls a long
 * page: the PageHeader carries the actions, the TopBar carries navigation
 * the user isn't using mid-page. So the TopBar slides away on scroll and the
 * PageHeader rises to take its place, giving detail pages back a full
 * header's worth of vertical space.
 *
 * The TopBar only retreats when a PageHeader is actually mounted to replace
 * it — on pages without one (list views), the search bar stays put.
 */
export function StickyHeaderProvider({ children }: { children: ReactNode }) {
  const [count, setCount] = useState(0)
  const scrolled = useScrolled(COLLAPSE_AT, RELEASE_AT)
  const hasPageHeader = count > 0

  const value = useMemo<StickyHeaderContextValue>(
    () => ({
      hasPageHeader,
      collapsed: scrolled && hasPageHeader,
      registerPageHeader: () => {
        setCount((n) => n + 1)
        return () => setCount((n) => n - 1)
      },
    }),
    [hasPageHeader, scrolled],
  )

  return <StickyHeaderContext.Provider value={value}>{children}</StickyHeaderContext.Provider>
}

/**
 * Reads the shared sticky-header state. Returns inert defaults outside a
 * provider so `PageHeader`/`TopBar` remain usable standalone (tests, plugin
 * previews) without throwing.
 */
export function useStickyHeader(): StickyHeaderContextValue {
  return (
    useContext(StickyHeaderContext) ?? {
      hasPageHeader: false,
      collapsed: false,
      registerPageHeader: () => () => {},
    }
  )
}

/**
 * Announces a mounted `PageHeader` for the lifetime of the calling component,
 * and reports whether the pair is currently collapsed.
 */
export function useRegisterPageHeader(): boolean {
  const { registerPageHeader, collapsed } = useStickyHeader()
  useEffect(() => registerPageHeader(), [registerPageHeader])
  return collapsed
}

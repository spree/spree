import { useSidebar } from '@spree/dashboard-ui'
import { useEffect, useRef } from 'react'

/**
 * Collapses the primary sidebar to its icon rail while `active` is true, and
 * restores the previous state when it goes false.
 *
 * Used by the settings area, where a second full-width nav appears beside the
 * primary one: two stacked 220px columns leave the settings forms squeezed, so
 * the primary nav folds down to icons for the duration.
 *
 * Only the entering and leaving transitions are driven — a manual toggle while
 * `active` stays true is left alone, and is what gets remembered on the way
 * out, so the merchant always keeps the last word.
 */
export function useAutoCollapseSidebar(active: boolean) {
  // Transient on purpose: this collapse is the app's doing, not the
  // merchant's, so it must not overwrite their remembered preference.
  const { open, setOpenTransient, isMobile } = useSidebar()
  // Reading `open` through a ref keeps it out of the effect's dependencies:
  // the effect must run on the `active` edges only, never on every toggle.
  const openRef = useRef(open)
  openRef.current = open
  const restoreTo = useRef<boolean | null>(null)

  useEffect(() => {
    // On mobile the primary nav is an overlay sheet, not a column competing
    // for width, so there is nothing to reclaim. Clearing the snapshot on the
    // way through matters: crossing the breakpoint mid-settings would
    // otherwise leave a stale value to restore from later.
    if (isMobile) {
      restoreTo.current = null
      return
    }

    if (active) {
      // Only snapshot on the way in. Re-running while already active (e.g.
      // navigating between two settings pages) must not re-capture a state
      // this hook itself imposed.
      if (restoreTo.current === null) restoreTo.current = openRef.current
      if (openRef.current) setOpenTransient(false)
      return
    }

    if (restoreTo.current !== null) {
      const wasOpenOnEntry = restoreTo.current
      restoreTo.current = null
      // Restore only if the rail is still collapsed — i.e. still as this hook
      // left it. A merchant who expanded it during settings has said what they
      // want, and forcing the entry-time value back would overrule them.
      if (wasOpenOnEntry && !openRef.current) setOpenTransient(true)
    }
  }, [active, isMobile, setOpenTransient])
}

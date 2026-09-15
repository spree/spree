import { useEffect, useRef } from 'react'

/**
 * Runs `seed` when a sheet or dialog goes from closed to open.
 *
 * Sheets stay mounted between opens, so their forms have to be reseeded from
 * the record each time one is opened. Depending on the record itself does that
 * too often: it is a new object on every refetch, and a background refetch
 * while the sheet is open would overwrite what the operator has typed. Keying
 * on the open transition reseeds exactly once per open.
 *
 * `seed` is read through a ref, so it does not need to be memoized by callers.
 */
export function useOnSheetOpen(open: boolean, seed: () => void) {
  const seedRef = useRef(seed)
  seedRef.current = seed

  const wasOpen = useRef(false)

  useEffect(() => {
    if (open && !wasOpen.current) seedRef.current()
    wasOpen.current = open
  }, [open])
}

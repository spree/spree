import { useCallback, useEffect, useRef, useState } from 'react'

interface UseCopyToClipboardOptions {
  /** Reset `copied` back to false after this many ms. Default 1200. */
  resetMs?: number
}

/**
 * Wraps `navigator.clipboard.writeText` with a `copied` flag that flashes true
 * for `resetMs` after a successful copy. `copy` resolves to whether it worked:
 * it fails in insecure contexts or when permission is denied, and the flag
 * then stays false.
 *
 * The reset timer is cleared on unmount so the component doesn't try to
 * `setState` after it's gone.
 */
export function useCopyToClipboard({ resetMs = 1200 }: UseCopyToClipboardOptions = {}) {
  const [copied, setCopied] = useState(false)
  const timerRef = useRef<number | null>(null)

  useEffect(() => {
    return () => {
      if (timerRef.current !== null) clearTimeout(timerRef.current)
    }
  }, [])

  const copy = useCallback(
    async (value: string): Promise<boolean> => {
      try {
        await navigator.clipboard.writeText(value)
        setCopied(true)
        if (timerRef.current !== null) clearTimeout(timerRef.current)
        timerRef.current = window.setTimeout(() => {
          setCopied(false)
          timerRef.current = null
        }, resetMs)
        return true
      } catch {
        return false
      }
    },
    [resetMs],
  )

  return { copied, copy }
}

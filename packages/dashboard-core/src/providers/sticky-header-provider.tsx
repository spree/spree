import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react'

/**
 * The CSS variable every pinned band offsets itself by — the table's pinned
 * column row, the bulk-action bar, scroll-margin on linked cards. It is
 * declared in `styles.css` with a fallback for pages that have no
 * `PageHeader`, and overwritten here with the real measurement when one is
 * mounted.
 */
const OFFSET_VARIABLE = '--spacing-header-height'

/**
 * Tracks a mounted `PageHeader` and publishes its height as the shared sticky
 * offset.
 *
 * The dashboard has no top bar: a page's own header is the only chrome above
 * the scrolling content, so it is also the only thing other pinned bands need
 * to clear. Its height is not a constant — badges, a subtitle and wrapped
 * actions all change it, and so does a narrow viewport — so it is measured
 * rather than assumed. A `ResizeObserver` keeps the variable current as the
 * header reflows.
 *
 * The variable is set on `document.documentElement` because the elements
 * reading it are not all descendants of the header (the pinned table row lives
 * further down the tree, and Tailwind resolves `top-header-height` against
 * whatever the cascade provides).
 *
 * @param enabled false for a header that does not pin — it then publishes no
 *   offset at all, so the bands below it pin to the top of the scroll
 *   container rather than clearing a header that never occupies that space.
 * @returns a ref to attach to the `PageHeader` element
 */
export function useStickyHeaderOffset(enabled = true): (node: HTMLElement | null) => void {
  const observerRef = useRef<ResizeObserver | null>(null)

  useEffect(() => {
    // Only on unmount: leaving a measured height behind would make the next
    // page — which may have no header at all — pin its table that far down.
    return () => {
      observerRef.current?.disconnect()
      document.documentElement.style.removeProperty(OFFSET_VARIABLE)
    }
  }, [])

  return useCallback(
    (node: HTMLElement | null) => {
      observerRef.current?.disconnect()

      if (!node || !enabled) {
        document.documentElement.style.removeProperty(OFFSET_VARIABLE)
        return
      }

      const publish = () => {
        const { height } = node.getBoundingClientRect()
        // Sub-pixel heights round up: rounding down leaves a hairline of the
        // scrolling row visible above the pinned one.
        document.documentElement.style.setProperty(OFFSET_VARIABLE, `${Math.ceil(height)}px`)
      }

      publish()

      if (typeof ResizeObserver !== 'undefined') {
        const observer = new ResizeObserver(publish)
        observer.observe(node)
        observerRef.current = observer
      }
    },
    [enabled],
  )
}

// ---------------------------------------------------------------------------
// Page-header presence — heading levels
// ---------------------------------------------------------------------------

const PageHeaderPresenceContext = createContext<{
  hasPageHeader: boolean
  register: () => () => void
} | null>(null)

/**
 * Tracks whether a `PageHeader` is mounted on the current page.
 *
 * This is not about layout — it is about heading levels. When a page has a
 * `PageHeader` it owns the `h1`, so a table heading below it must be an `h2`;
 * on a page without one the table's own title is the first heading. Getting
 * that wrong produces a document with two `h1`s or none, which is exactly what
 * a screen-reader user navigates by.
 */
export function StickyHeaderProvider({ children }: { children: ReactNode }) {
  const [count, setCount] = useState(0)

  const value = useMemo(
    () => ({
      hasPageHeader: count > 0,
      register: () => {
        setCount((n) => n + 1)
        return () => setCount((n) => n - 1)
      },
    }),
    [count],
  )

  return (
    <PageHeaderPresenceContext.Provider value={value}>
      {children}
    </PageHeaderPresenceContext.Provider>
  )
}

/**
 * Whether a `PageHeader` is mounted. Returns an inert default outside a
 * provider so components stay usable standalone (tests, plugin previews).
 */
export function useStickyHeader(): { hasPageHeader: boolean } {
  return useContext(PageHeaderPresenceContext) ?? { hasPageHeader: false }
}

/** Announces a mounted `PageHeader` for the lifetime of the calling component. */
export function useRegisterPageHeader(): void {
  const ctx = useContext(PageHeaderPresenceContext)
  const register = ctx?.register
  useEffect(() => register?.(), [register])
}

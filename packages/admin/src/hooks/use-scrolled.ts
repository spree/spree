import * as React from 'react'

/**
 * Returns true once the document has been scrolled past `threshold` pixels
 * from the top, false at rest. Used to fade in subtle elevation on sticky
 * headers, top bars, etc. so they don't look heavy when nothing is scrolled
 * behind them.
 *
 * Listens passively to `window` scroll. Default threshold is 4px to avoid
 * flickering at the boundary on devices that report fractional scroll
 * positions. Initial value is computed synchronously on mount so the first
 * paint matches the actual scroll position (e.g., after browser scroll
 * restoration on navigation).
 */
export function useScrolled(threshold = 4) {
  // Always start `false` so a future SSR render and the first client paint
  // agree (no hydration mismatch). The effect below resyncs against the
  // actual scroll position on mount, so any restored scroll position is
  // reflected as soon as the effect runs.
  const [scrolled, setScrolled] = React.useState(false)

  React.useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > threshold)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [threshold])

  return scrolled
}

import * as React from 'react'

/**
 * Returns true once the document has been scrolled past `threshold` pixels
 * from the top, false at rest. Used to fade in subtle elevation on sticky
 * headers, top bars, etc. so they don't look heavy when nothing is scrolled
 * behind them.
 *
 * Listens passively to `window` scroll. Default threshold is 4px to avoid
 * flickering at the boundary on devices that report fractional scroll
 * positions.
 *
 * @param threshold Scroll offset, in pixels, at which the state flips to true.
 * @param releaseThreshold Offset the user must scroll back above before it
 *   flips to false again. Defaults to `threshold` (no hysteresis). Set it
 *   lower than `threshold` when the flag drives motion: a single boundary
 *   makes a slow scroll across it toggle repeatedly, and anything animating
 *   off this flag then flickers.
 */
export function useScrolled(threshold = 4, releaseThreshold = threshold) {
  // Always start `false` so a future SSR render and the first client paint
  // agree (no hydration mismatch). The effect below resyncs against the
  // actual scroll position on mount, so any restored scroll position is
  // reflected as soon as the effect runs.
  const [scrolled, setScrolled] = React.useState(false)

  React.useEffect(() => {
    const onScroll = () =>
      // Reading the previous value here (rather than from a dependency) keeps
      // the listener stable while still letting the two thresholds apply
      // directionally: past `threshold` to engage, back above
      // `releaseThreshold` to disengage.
      setScrolled((wasScrolled) =>
        wasScrolled ? window.scrollY > releaseThreshold : window.scrollY > threshold,
      )
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [threshold, releaseThreshold])

  return scrolled
}
